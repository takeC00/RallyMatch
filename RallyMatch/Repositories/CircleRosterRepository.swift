import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class CircleRosterRepository {
    static let shared = CircleRosterRepository()

    private(set) var playersByCircle: [String: [RosterPlayer]] = [:]
    private(set) var isLoadingCircleIds: Set<String> = []
    var lastError: String?

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func players(for circleId: String) -> [RosterPlayer] {
        playersByCircle[circleId] ?? []
    }

    func refresh(circleId: String) async {
        isLoadingCircleIds.insert(circleId)
        defer { isLoadingCircleIds.remove(circleId) }

        do {
            try await purgeExpiredVisitors(circleId: circleId)

            let snapshot = try await db.collection("circleRoster")
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()

            let players = snapshot.documents
                .compactMap { RosterPlayer.from($0) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            playersByCircle[circleId] = players
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshAll(circleIds: [String]) async {
        for circleId in circleIds {
            await refresh(circleId: circleId)
        }
    }

    func addPlayer(circleId: String, name: String, level: PlayerLevel) async throws -> RosterPlayer {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RosterError.invalidName
        }

        let existing = players(for: circleId)
        let memberNames = CircleMembersRepository.shared
            .members(for: circleId)
            .map(\.userName)
        if existing.contains(where: { $0.name == trimmed })
            || memberNames.contains(trimmed) {
            throw RosterError.duplicateName
        }

        let playerId = UUID()
        let player = RosterPlayer(
            id: RosterPlayer.documentId(circleId: circleId, playerId: playerId),
            playerId: playerId,
            circleId: circleId,
            name: trimmed,
            level: level,
            createdAt: Date()
        )

        try await db.collection("circleRoster")
            .document(player.id)
            .setData(player.toDictionary())

        await refresh(circleId: circleId)
        return player
    }

    func updatePlayer(_ player: RosterPlayer, name: String, level: PlayerLevel) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw RosterError.invalidName
        }

        let existing = players(for: player.circleId)
        if existing.contains(where: { $0.name == trimmed && $0.id != player.id }) {
            throw RosterError.duplicateName
        }

        try await db.collection("circleRoster")
            .document(player.id)
            .updateData([
                "name": trimmed,
                "level": level.rawValue
            ])

        await refresh(circleId: player.circleId)
    }

    func updateLevel(_ player: RosterPlayer, level: PlayerLevel) async throws {
        try await db.collection("circleRoster")
            .document(player.id)
            .updateData(["level": level.rawValue])
        await refresh(circleId: player.circleId)
    }

    func upsertMember(_ member: CloudCircleMember, level: PlayerLevel) async throws {
        switch member.memberType {
        case .registered:
            guard let userId = member.userId else { return }
            try await upsertRegisteredMember(member, userId: userId, level: level)
        case .manual:
            try await upsertManualMember(member, level: level)
        }
    }

    /// 後方互換
    func upsertLinkedMember(_ member: CloudCircleMember, level: PlayerLevel) async throws {
        try await upsertMember(member, level: level)
    }

    private func upsertRegisteredMember(
        _ member: CloudCircleMember,
        userId: String,
        level: PlayerLevel
    ) async throws {
        let playerId = PlayerIdentity.stablePlayerId(userId: userId)
        let documentId = RosterPlayer.linkedDocumentId(
            circleId: member.circleId,
            userId: userId
        )
        let ref = db.collection("circleRoster").document(documentId)
        let now = Timestamp(date: .now)

        let data: [String: Any] = [
            "circleId": member.circleId,
            "playerId": playerId.uuidString.lowercased(),
            "name": member.userName,
            "level": level.rawValue,
            "userId": userId,
            "memberType": MemberType.registered.rawValue,
            "createdAt": Timestamp(date: member.joinedAt),
            "updatedAt": now,
        ]

        try await ref.setData(data, merge: true)
        await refresh(circleId: member.circleId)
    }

    private func upsertManualMember(_ member: CloudCircleMember, level: PlayerLevel) async throws {
        let playerId = PlayerIdentity.stablePlayerId(circleMemberDocumentId: member.id)
        let ref = db.collection("circleRoster").document(member.id)
        let now = Timestamp(date: .now)

        let data: [String: Any] = [
            "circleId": member.circleId,
            "playerId": playerId.uuidString.lowercased(),
            "name": member.userName,
            "level": level.rawValue,
            "circleMemberId": member.id,
            "memberType": MemberType.manual.rawValue,
            "createdAt": Timestamp(date: member.joinedAt),
            "updatedAt": now,
        ]

        try await ref.setData(data, merge: true)
        await refresh(circleId: member.circleId)
    }

    func linkedPlayer(circleId: String, userId: String) -> RosterPlayer? {
        players(for: circleId).first { $0.linkedUserId == userId }
    }

    func manualPlayer(circleId: String, circleMemberId: String) -> RosterPlayer? {
        players(for: circleId).first { $0.circleMemberId == circleMemberId || $0.id == circleMemberId }
    }

    func rosterPlayer(for member: CloudCircleMember) -> RosterPlayer? {
        switch member.memberType {
        case .registered:
            guard let userId = member.userId else { return nil }
            return linkedPlayer(circleId: member.circleId, userId: userId)
        case .manual:
            return manualPlayer(circleId: member.circleId, circleMemberId: member.id)
        }
    }

    func deleteVisitor(_ player: RosterPlayer) async throws {
        guard player.isLegacyDayVisitor else {
            throw RosterError.cannotDeleteLinkedMember
        }
        try await deletePlayer(player)
    }

    func deletePlayer(_ player: RosterPlayer) async throws {
        try await db.collection("circleRoster")
            .document(player.id)
            .delete()

        await refresh(circleId: player.circleId)
    }

    /// 前日以前に登録された Visitor を削除（アカウント連携メンバーは対象外）
    @discardableResult
    func purgeExpiredVisitors(circleId: String) async throws -> Int {
        let snapshot = try await db.collection("circleRoster")
            .whereField("circleId", isEqualTo: circleId)
            .getDocuments()

        let expired = snapshot.documents.compactMap { RosterPlayer.from($0) }
            .filter { $0.isLegacyDayVisitor && VisitorExpiry.isExpired(createdAt: $0.createdAt) }

        guard !expired.isEmpty else { return 0 }

        let batch = db.batch()
        for player in expired {
            batch.deleteDocument(db.collection("circleRoster").document(player.id))
        }
        try await batch.commit()
        return expired.count
    }
}

enum RosterError: LocalizedError {
    case invalidName
    case duplicateName
    case cannotDeleteLinkedMember

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "名前を入力してください"
        case .duplicateName:
            "同じ名前の参加者が既にいます"
        case .cannotDeleteLinkedMember:
            "アカウントメンバーはここから削除できません"
        }
    }
}

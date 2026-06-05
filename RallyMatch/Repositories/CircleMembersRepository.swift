import Foundation
import FirebaseFirestore
import Observation

@MainActor
@Observable
final class CircleMembersRepository {
    static let shared = CircleMembersRepository()

    private(set) var membersByCircle: [String: [CloudCircleMember]] = [:]
    private(set) var isLoadingCircleIds: Set<String> = []
    var lastError: String?

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func members(for circleId: String) -> [CloudCircleMember] {
        membersByCircle[circleId] ?? []
    }

    func registeredMembers(for circleId: String) -> [CloudCircleMember] {
        members(for: circleId).filter(\.isRegistered)
    }

    func manualMembers(for circleId: String) -> [CloudCircleMember] {
        members(for: circleId).filter(\.isManual)
    }

    func refresh(circleId: String) async {
        isLoadingCircleIds.insert(circleId)
        defer { isLoadingCircleIds.remove(circleId) }

        do {
            let snapshot = try await db.collection("circleMembers")
                .whereField("circleId", isEqualTo: circleId)
                .getDocuments()

            let members = snapshot.documents
                .compactMap { CloudCircleMember.from($0) }
                .sorted { $0.userName.localizedCaseInsensitiveCompare($1.userName) == .orderedAscending }

            membersByCircle[circleId] = members
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

    /// 手動登録メンバーを作成（Firebase Auth なし・永続管理）
    func createManualMember(
        circleId: String,
        displayName: String,
        rating: Int = 1500,
        level: PlayerLevel,
        notes: String?,
        createdBy: String
    ) async throws -> CloudCircleMember {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MemberError.invalidName
        }

        if membersByCircle[circleId] == nil {
            await refresh(circleId: circleId)
        }

        let existingNames = members(for: circleId).map(\.userName)
        if existingNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw MemberError.duplicateName
        }

        let memberId = UUID().uuidString.lowercased()
        let documentId = CloudCircleMember.manualDocumentId(circleId: circleId, memberId: memberId)
        let now = Date()

        let member = CloudCircleMember(
            id: documentId,
            circleId: circleId,
            userId: nil,
            userName: trimmed,
            rating: rating,
            role: "member",
            memberType: .manual,
            level: level,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            isActive: true,
            createdBy: createdBy,
            joinedAt: now,
            updatedAt: now
        )

        try await db.collection("circleMembers")
            .document(documentId)
            .setData(member.toDictionary(createdByUid: createdBy))

        await refresh(circleId: circleId)
        try await syncMembersToRoster(circleId: circleId)
        return member
    }

    func updateManualMember(
        _ member: CloudCircleMember,
        displayName: String,
        rating: Int,
        level: PlayerLevel,
        notes: String?
    ) async throws {
        guard member.isManual else {
            throw MemberError.notManualMember
        }

        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MemberError.invalidName
        }

        try await db.collection("circleMembers")
            .document(member.id)
            .updateData([
                "userName": trimmed,
                "displayName": trimmed,
                "rating": rating,
                "level": level.rawValue,
                "notes": notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? NSNull(),
                "updatedAt": Timestamp(date: .now),
            ])

        await refresh(circleId: member.circleId)
        try await syncMembersToRoster(circleId: member.circleId)
    }

    func deactivateManualMember(_ member: CloudCircleMember) async throws {
        guard member.isManual else {
            throw MemberError.notManualMember
        }

        try await db.collection("circleMembers")
            .document(member.id)
            .updateData([
                "isActive": false,
                "updatedAt": Timestamp(date: .now),
            ])

        try await db.collection("circleRoster")
            .document(member.id)
            .delete()

        await refresh(circleId: member.circleId)
        await CircleRosterRepository.shared.refresh(circleId: member.circleId)
    }

    func removeRegisteredMember(_ member: CloudCircleMember) async throws {
        guard member.isRegistered, let userId = member.userId else {
            throw MemberError.notRegisteredMember
        }

        let circleRef = db.collection("circles").document(member.circleId)
        let memberRef = db.collection("circleMembers").document(member.id)
        let rosterRef = db.collection("circleRoster").document(
            PlayerIdentity.linkedRosterDocumentId(circleId: member.circleId, userId: userId)
        )

        try await db.runTransaction { transaction, errorPointer in
            transaction.deleteDocument(memberRef)
            transaction.updateData([
                "memberIds": FieldValue.arrayRemove([userId]),
                "updatedAt": Timestamp(date: .now),
            ], forDocument: circleRef)
            transaction.deleteDocument(rosterRef)
            return nil
        }

        await refresh(circleId: member.circleId)
        await CircleRosterRepository.shared.refresh(circleId: member.circleId)
    }

    func removeMember(_ member: CloudCircleMember) async throws {
        if member.isManual {
            try await deactivateManualMember(member)
        } else {
            try await removeRegisteredMember(member)
        }
    }

    func updateRegisteredMember(
        _ member: CloudCircleMember,
        rating: Int,
        level: PlayerLevel,
        notes: String?
    ) async throws {
        guard member.isRegistered else {
            throw MemberError.notRegisteredMember
        }

        try await db.collection("circleMembers")
            .document(member.id)
            .updateData([
                "rating": rating,
                "level": level.rawValue,
                "notes": notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? NSNull(),
                "updatedAt": Timestamp(date: .now),
            ])

        try await CircleRosterRepository.shared.upsertLinkedMember(member, level: level)
        await refresh(circleId: member.circleId)
    }

    /// `circleMembers` を `circleRoster` に同期（Mate / Hub で参加したメンバーを Match 試合生成に使えるようにする）
    func syncMembersToRoster(circleId: String) async throws {
        if membersByCircle[circleId] == nil {
            await refresh(circleId: circleId)
        }

        let members = members(for: circleId)
        let now = Timestamp(date: .now)

        for member in members {
            let ref: DocumentReference
            let playerId: UUID
            var data: [String: Any] = [
                "circleId": circleId,
                "name": member.userName,
                "memberType": member.memberType.rawValue,
                "updatedAt": now,
            ]

            switch member.memberType {
            case .registered:
                guard let userId = member.userId else { continue }
                playerId = PlayerIdentity.stablePlayerId(userId: userId)
                ref = db.collection("circleRoster").document(
                    PlayerIdentity.linkedRosterDocumentId(circleId: circleId, userId: userId)
                )
                data["playerId"] = playerId.uuidString.lowercased()
                data["userId"] = userId

            case .manual:
                playerId = PlayerIdentity.stablePlayerId(circleMemberDocumentId: member.id)
                ref = db.collection("circleRoster").document(member.id)
                data["playerId"] = playerId.uuidString.lowercased()
                data["circleMemberId"] = member.id
            }

            data["level"] = (member.level ?? .experienced).rawValue
            data["createdAt"] = Timestamp(date: member.joinedAt)

            try await ref.setData(data, merge: true)
        }

        await CircleRosterRepository.shared.refresh(circleId: circleId)
    }

    func syncAllJoinedCircles(_ circleIds: [String]) async {
        for circleId in circleIds {
            do {
                try await syncMembersToRoster(circleId: circleId)
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

enum MemberError: LocalizedError {
    case invalidName
    case duplicateName
    case notManualMember
    case notRegisteredMember

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "表示名を入力してください"
        case .duplicateName:
            "同じ名前のメンバーが既にいます"
        case .notManualMember:
            "手動登録メンバーのみ操作できます"
        case .notRegisteredMember:
            "アカウントメンバーのみ操作できます"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

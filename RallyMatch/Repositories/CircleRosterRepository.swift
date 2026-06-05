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
        if existing.contains(where: { $0.name == trimmed }) {
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

    func deletePlayer(_ player: RosterPlayer) async throws {
        try await db.collection("circleRoster")
            .document(player.id)
            .delete()

        await refresh(circleId: player.circleId)
    }
}

enum RosterError: LocalizedError {
    case invalidName
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "名前を入力してください"
        case .duplicateName:
            "同じ名前の参加者が既にいます"
        }
    }
}

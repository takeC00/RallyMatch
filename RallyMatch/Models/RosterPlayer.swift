import Foundation
import FirebaseFirestore

/// サークルに紐づく試合用参加者（Firestore `circleRoster`）
struct RosterPlayer: Identifiable, Hashable, Sendable {
    let id: String
    let playerId: UUID
    let circleId: String
    let name: String
    let level: PlayerLevel
    let createdAt: Date

    static func documentId(circleId: String, playerId: UUID) -> String {
        "\(circleId)_\(playerId.uuidString.lowercased())"
    }

    func toDictionary() -> [String: Any] {
        [
            "circleId": circleId,
            "playerId": playerId.uuidString.lowercased(),
            "name": name,
            "level": level.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }

    static func from(_ document: DocumentSnapshot) -> RosterPlayer? {
        guard let data = document.data(),
              let circleId = data["circleId"] as? String,
              let name = data["name"] as? String,
              let levelRaw = data["level"] as? String,
              let level = PlayerLevel(rawValue: levelRaw)
        else { return nil }

        let playerIdString = (data["playerId"] as? String) ?? document.documentID
        let playerId = UUID(uuidString: playerIdString)
            ?? UUID(uuidString: document.documentID.split(separator: "_").last.map(String.init) ?? "")
            ?? UUID()

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return RosterPlayer(
            id: document.documentID,
            playerId: playerId,
            circleId: circleId,
            name: name,
            level: level,
            createdAt: createdAt
        )
    }
}

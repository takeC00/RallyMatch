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
    /// アカウント連携済みメンバー（`circleMembers.userId`）
    let linkedUserId: String?

    var isLinkedAccount: Bool { linkedUserId != nil }

    static func documentId(circleId: String, playerId: UUID) -> String {
        "\(circleId)_\(playerId.uuidString.lowercased())"
    }

    static func linkedDocumentId(circleId: String, userId: String) -> String {
        PlayerIdentity.linkedRosterDocumentId(circleId: circleId, userId: userId)
    }

    init(
        id: String,
        playerId: UUID,
        circleId: String,
        name: String,
        level: PlayerLevel,
        createdAt: Date,
        linkedUserId: String? = nil
    ) {
        self.id = id
        self.playerId = playerId
        self.circleId = circleId
        self.name = name
        self.level = level
        self.createdAt = createdAt
        self.linkedUserId = linkedUserId
    }

    init(from member: CloudCircleMember) {
        let playerId = PlayerIdentity.stablePlayerId(userId: member.userId)
        self.id = Self.linkedDocumentId(circleId: member.circleId, userId: member.userId)
        self.playerId = playerId
        self.circleId = member.circleId
        self.name = member.userName
        self.level = .experienced
        self.createdAt = member.joinedAt
        self.linkedUserId = member.userId
    }

    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "circleId": circleId,
            "playerId": playerId.uuidString.lowercased(),
            "name": name,
            "level": level.rawValue,
            "createdAt": Timestamp(date: createdAt),
        ]
        if let linkedUserId {
            data["userId"] = linkedUserId
        }
        return data
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
        let linkedUserId = data["userId"] as? String

        return RosterPlayer(
            id: document.documentID,
            playerId: playerId,
            circleId: circleId,
            name: name,
            level: level,
            createdAt: createdAt,
            linkedUserId: linkedUserId
        )
    }
}

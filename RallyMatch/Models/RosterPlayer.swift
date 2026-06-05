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
    /// 手動登録メンバーの `circleMembers` ドキュメント ID
    let circleMemberId: String?
    let memberType: MemberType?

    var isLinkedAccount: Bool {
        memberType == .registered || (linkedUserId != nil && circleMemberId == nil)
    }

    var isManualMember: Bool {
        memberType == .manual || circleMemberId != nil
    }

    /// 旧 circleRoster の一日 Visitor（後方互換・自動削除対象）
    var isLegacyDayVisitor: Bool {
        !isLinkedAccount && !isManualMember
    }

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
        linkedUserId: String? = nil,
        circleMemberId: String? = nil,
        memberType: MemberType? = nil
    ) {
        self.id = id
        self.playerId = playerId
        self.circleId = circleId
        self.name = name
        self.level = level
        self.createdAt = createdAt
        self.linkedUserId = linkedUserId
        self.circleMemberId = circleMemberId
        self.memberType = memberType
    }

    init(from member: CloudCircleMember) {
        switch member.memberType {
        case .registered:
            guard let userId = member.userId else {
                fatalError("registered member requires userId")
            }
            let playerId = PlayerIdentity.stablePlayerId(userId: userId)
            self.id = Self.linkedDocumentId(circleId: member.circleId, userId: userId)
            self.playerId = playerId
            self.linkedUserId = userId
            self.circleMemberId = nil
            self.memberType = .registered
        case .manual:
            let playerId = PlayerIdentity.stablePlayerId(circleMemberDocumentId: member.id)
            self.id = member.id
            self.playerId = playerId
            self.linkedUserId = nil
            self.circleMemberId = member.id
            self.memberType = .manual
        }
        self.circleId = member.circleId
        self.name = member.userName
        self.level = member.level ?? .experienced
        self.createdAt = member.joinedAt
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
        if let circleMemberId {
            data["circleMemberId"] = circleMemberId
        }
        if let memberType {
            data["memberType"] = memberType.rawValue
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
        let circleMemberId = data["circleMemberId"] as? String
        let memberType = (data["memberType"] as? String).map(MemberType.fromFirestore)

        return RosterPlayer(
            id: document.documentID,
            playerId: playerId,
            circleId: circleId,
            name: name,
            level: level,
            createdAt: createdAt,
            linkedUserId: linkedUserId,
            circleMemberId: circleMemberId,
            memberType: memberType
        )
    }
}

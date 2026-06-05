import Foundation
import FirebaseFirestore

/// Firestore `circleMembers.memberType`（RallyOS 共通）
enum MemberType: String, Codable, Sendable, Hashable, CaseIterable {
    /// Firebase Auth ありの正式メンバー
    case registered
    /// 主催者が手動登録した永続メンバー（Auth なし）
    case manual

    var displayName: String {
        switch self {
        case .registered: "メンバー"
        case .manual: "手動登録"
        }
    }

    static func fromFirestore(_ raw: String?) -> MemberType {
        guard let raw else { return .registered }
        return MemberType(rawValue: raw) ?? .registered
    }
}

/// Firestore `circleMembers`（Hub / Mate / Match 共通）
struct CloudCircleMember: Identifiable, Hashable, Sendable {
    let id: String
    let circleId: String
    /// 正式メンバーの Firebase Auth UID。手動登録の場合は nil
    let userId: String?
    let userName: String
    let rating: Int
    let role: String
    let memberType: MemberType
    let level: PlayerLevel?
    let notes: String?
    let isActive: Bool
    let createdBy: String?
    let joinedAt: Date
    let updatedAt: Date?

    var isRegistered: Bool { memberType == .registered }
    var isManual: Bool { memberType == .manual }

    /// Mate 試合・レーティングで使う参加者 ID
    var matchParticipantId: String {
        switch memberType {
        case .registered:
            return userId ?? id
        case .manual:
            return ManualMemberIdentity.playerId(circleMemberDocumentId: id)
        }
    }

    static func documentId(circleId: String, userId: String) -> String {
        "\(circleId)_\(userId)"
    }

    static func manualDocumentId(circleId: String, memberId: String) -> String {
        "\(circleId)_\(memberId)"
    }

    static func from(_ document: DocumentSnapshot) -> CloudCircleMember? {
        guard let data = document.data() else { return nil }
        guard let circleId = data["circleId"] as? String else { return nil }

        let userName = (data["userName"] as? String)
            ?? (data["displayName"] as? String)
            ?? (data["nickname"] as? String)
            ?? ""
        guard !userName.isEmpty else { return nil }

        let userId = data["userId"] as? String
        let memberType: MemberType
        if let raw = data["memberType"] as? String {
            memberType = MemberType.fromFirestore(raw)
        } else if userId != nil {
            memberType = .registered
        } else {
            return nil
        }

        if memberType == .registered && userId == nil { return nil }
        if memberType == .manual && userId != nil { return nil }

        let rating = intValue(from: data["rating"]) ?? 1500
        let role = (data["role"] as? String) ?? "member"
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()
            ?? (data["createdAt"] as? Timestamp)?.dateValue()
            ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()
        let levelRaw = data["level"] as? String
        let level = levelRaw.flatMap { PlayerLevel(rawValue: $0) }
        let notes = data["notes"] as? String
        let isActive = data["isActive"] as? Bool ?? true
        let createdBy = data["createdBy"] as? String

        guard isActive else { return nil }

        return CloudCircleMember(
            id: document.documentID,
            circleId: circleId,
            userId: userId,
            userName: userName,
            rating: rating,
            role: role,
            memberType: memberType,
            level: level,
            notes: notes,
            isActive: isActive,
            createdBy: createdBy,
            joinedAt: joinedAt,
            updatedAt: updatedAt
        )
    }

    func toDictionary(createdByUid: String? = nil) -> [String: Any] {
        var data: [String: Any] = [
            "circleId": circleId,
            "userName": userName,
            "displayName": userName,
            "rating": rating,
            "role": role,
            "memberType": memberType.rawValue,
            "isActive": isActive,
            "joinedAt": Timestamp(date: joinedAt),
            "updatedAt": Timestamp(date: updatedAt ?? .now),
        ]

        if let userId {
            data["userId"] = userId
        }
        if let level {
            data["level"] = level.rawValue
        }
        if let notes, !notes.isEmpty {
            data["notes"] = notes
        }
        if let creator = createdBy ?? createdByUid {
            data["createdBy"] = creator
        }

        return data
    }

    private static func intValue(from value: Any?) -> Int? {
        switch value {
        case let number as Int: number
        case let number as Int64: Int(number)
        case let number as Double: Int(number)
        default: nil
        }
    }
}

extension CloudCircleMember {
    static func == (lhs: CloudCircleMember, rhs: CloudCircleMember) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

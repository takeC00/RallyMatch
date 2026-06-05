import Foundation
import FirebaseFirestore

/// Firestore `circleMembers`（Hub / Mate / Match 共通）
struct CloudCircleMember: Identifiable, Hashable, Sendable {
    let id: String
    let circleId: String
    let userId: String
    let userName: String
    let rating: Int
    let role: String
    let joinedAt: Date

    static func documentId(circleId: String, userId: String) -> String {
        "\(circleId)_\(userId)"
    }

    static func from(_ document: DocumentSnapshot) -> CloudCircleMember? {
        guard let data = document.data() else { return nil }
        guard
            let circleId = data["circleId"] as? String,
            let userId = data["userId"] as? String
        else { return nil }

        let userName = (data["userName"] as? String)
            ?? (data["nickname"] as? String)
            ?? ""
        guard !userName.isEmpty else { return nil }

        let rating = intValue(from: data["rating"]) ?? 1500
        let role = (data["role"] as? String) ?? "member"
        let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue() ?? Date()

        return CloudCircleMember(
            id: document.documentID,
            circleId: circleId,
            userId: userId,
            userName: userName,
            rating: rating,
            role: role,
            joinedAt: joinedAt
        )
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

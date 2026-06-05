import Foundation
import FirebaseFirestore

/// Firestore `circles` コレクション（Hub / Mate と共通）
struct CloudCircle: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let sportName: String
    let location: String
    let circleCode: String
    let ownerId: String
    let memberIds: [String]
    let createdAt: Date

    var memberCount: Int { memberIds.count }

    static func from(_ document: DocumentSnapshot) -> CloudCircle? {
        from(data: document.data() ?? [:], id: document.documentID)
    }

    static func from(data: [String: Any], id: String) -> CloudCircle? {
        guard
            let name = data["name"] as? String,
            let ownerId = data["ownerId"] as? String
        else { return nil }

        let description = data["description"] as? String ?? ""
        let sportName = data["sportName"] as? String ?? RallySportOptions.defaultSport
        let location = data["location"] as? String ?? ""
        let circleCode = (data["circleCode"] as? String)
            ?? String(id.prefix(6)).uppercased()
        let memberIds = data["memberIds"] as? [String] ?? []
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        return CloudCircle(
            id: id,
            name: name,
            description: description,
            sportName: sportName,
            location: location,
            circleCode: circleCode,
            ownerId: ownerId,
            memberIds: memberIds,
            createdAt: createdAt
        )
    }
}

import Foundation
import SwiftData

@Model
final class Circle {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    /// クラウド上の現行セッション（1サークル1セッション）
    var activeSessionId: String?

    @Relationship(deleteRule: .cascade, inverse: \Player.circle)
    var players: [Player] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

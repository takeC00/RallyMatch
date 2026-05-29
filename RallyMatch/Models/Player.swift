import Foundation
import SwiftData

@Model
final class Player {
    @Attribute(.unique) var id: UUID
    var circleId: UUID
    var name: String
    var levelRaw: String
    var createdAt: Date

    var circle: Circle?

    var level: PlayerLevel {
        get { PlayerLevel(rawValue: levelRaw) ?? .beginner }
        set { levelRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        circleId: UUID,
        name: String,
        level: PlayerLevel,
        createdAt: Date = .now
    ) {
        self.id = id
        self.circleId = circleId
        self.name = name
        self.levelRaw = level.rawValue
        self.createdAt = createdAt
    }
}

import Foundation

struct SessionPlayer: Identifiable, Hashable {
    let id: UUID
    var name: String
    var level: PlayerLevel

    init(id: UUID = UUID(), name: String, level: PlayerLevel) {
        self.id = id
        self.name = name
        self.level = level
    }

    init(from player: RosterPlayer) {
        self.id = player.playerId
        self.name = player.name
        self.level = player.level
    }
}

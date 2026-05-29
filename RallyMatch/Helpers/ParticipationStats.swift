import Foundation

struct PlayerParticipation: Identifiable {
    let player: SessionPlayer
    let matchCount: Int

    var id: UUID { player.id }
}

enum ParticipationStats {
    static func counts(
        players: [SessionPlayer],
        matches: [GeneratedMatch]
    ) -> [PlayerParticipation] {
        let active = matches.filter { $0.status != .cancelled }

        return players
            .map { player in
                let count = active.filter { $0.playerIds.contains(player.id) }.count
                return PlayerParticipation(player: player, matchCount: count)
            }
            .sorted { lhs, rhs in
                if lhs.matchCount != rhs.matchCount {
                    return lhs.matchCount < rhs.matchCount
                }
                return lhs.player.name < rhs.player.name
            }
    }
}

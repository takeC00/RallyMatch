import Foundation

enum MatchRoundHelper {
    /// 1巡 = 全参加者が最低1回試合に出場し終わるまで。2巡 = 全員が2回目まで、以降同様。
    static func groups(
        from matches: [GeneratedMatch],
        playerIds: [UUID]
    ) -> [(round: Int, matches: [GeneratedMatch])] {
        let active = matches
            .filter { $0.status != .cancelled }
            .sorted { $0.matchNo < $1.matchNo }

        guard !active.isEmpty else { return [] }

        let participants = Set(playerIds)
        var counts = Dictionary(uniqueKeysWithValues: playerIds.map { ($0, 0) })
        var currentRound = 1
        var dict: [Int: [GeneratedMatch]] = [:]

        for match in active {
            dict[currentRound, default: []].append(match)

            for id in match.playerIds where participants.contains(id) {
                counts[id, default: 0] += 1
            }

            if participants.allSatisfy({ counts[$0, default: 0] >= currentRound }) {
                currentRound += 1
            }
        }

        return dict.keys.sorted().map { round in
            (round: round, matches: dict[round] ?? [])
        }
    }
}

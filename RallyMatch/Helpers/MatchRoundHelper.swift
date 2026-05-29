import Foundation

enum MatchRoundHelper {
    /// 1巡 = 全参加者が最低1回試合に出場し終わるまで。2巡 = 全員が2回目まで、以降同様。
    static func assignRounds(
        to matches: [GeneratedMatch],
        playerIds: [UUID]
    ) -> [GeneratedMatch] {
        let roundById = computeRoundMap(
            matches: matches.filter { $0.status != .cancelled },
            playerIds: playerIds
        )

        return matches.map { match in
            var updated = match
            if match.status != .cancelled, let round = roundById[match.id] {
                updated.roundNo = round
            }
            return updated
        }
    }

    /// 保存済みの roundNo でグループ化（試合済みを除いても巡番号は変わらない）
    static func groupsByStoredRound(
        from matches: [GeneratedMatch]
    ) -> [(round: Int, matches: [GeneratedMatch])] {
        var dict: [Int: [GeneratedMatch]] = [:]
        for match in matches.sorted(by: { $0.matchNo < $1.matchNo }) {
            let round = max(1, match.roundNo)
            dict[round, default: []].append(match)
        }
        return dict.keys.sorted().map { round in
            (round: round, matches: dict[round] ?? [])
        }
    }

    private static func computeRoundMap(
        matches: [GeneratedMatch],
        playerIds: [UUID]
    ) -> [UUID: Int] {
        let active = matches.sorted { $0.matchNo < $1.matchNo }
        guard !active.isEmpty else { return [:] }

        let participants = Set(playerIds)
        var counts = Dictionary(uniqueKeysWithValues: playerIds.map { ($0, 0) })
        var currentRound = 1
        var result: [UUID: Int] = [:]

        for match in active {
            result[match.id] = currentRound

            for id in match.playerIds where participants.contains(id) {
                counts[id, default: 0] += 1
            }

            if participants.allSatisfy({ counts[$0, default: 0] >= currentRound }) {
                currentRound += 1
            }
        }

        return result
    }
}

import Foundation

/// ダブルス試合を生成。全員が目標試合数に近づくよう、出場回数の少ない選手を優先する。
struct MatchGenerator {
    private static let maxCandidatePoolSize = 14

    /// 生成ごとに変わる並び・同点時の選び方（同じ参加者でも毎回組み合わせが変わる）
    private struct GenerationRandomness {
        private let playerOrder: [UUID: Int]

        init(players: [SessionPlayer]) {
            var order: [UUID: Int] = [:]
            for (index, player) in players.shuffled().enumerated() {
                order[player.id] = index
            }
            playerOrder = order
        }

        func prefersFirst(_ a: UUID, _ b: UUID) -> Bool {
            (playerOrder[a] ?? Int.max) < (playerOrder[b] ?? Int.max)
        }
    }
    private struct PlayerState {
        let player: SessionPlayer
        var matchCount: Int = 0
        var lastMatchIndex: Int?
        var consecutiveRests: Int = 0
    }

    private struct History {
        var pairCounts: [PairKey: Int] = [:]
        var opponentCounts: [OpponentKey: Int] = [:]
    }

    private struct PairKey: Hashable {
        let a: UUID
        let b: UUID

        init(_ x: UUID, _ y: UUID) {
            if x.uuidString < y.uuidString { a = x; b = y }
            else { a = y; b = x }
        }
    }

    private struct OpponentKey: Hashable {
        let a: UUID
        let b: UUID

        init(_ x: UUID, _ y: UUID) {
            if x.uuidString < y.uuidString { a = x; b = y }
            else { a = y; b = x }
        }
    }

    static func generate(
        players: [SessionPlayer],
        mode: GenerationMode,
        matchPerPlayer: Int,
        courtCount: Int,
        existingDone: [GeneratedMatch] = [],
        startingMatchNo: Int = 1
    ) -> [GeneratedMatch] {
        guard players.count >= 4 else { return existingDone.filter { $0.status == .done } }

        let target = max(1, matchPerPlayer)
        let randomness = GenerationRandomness(players: players)
        var states = buildInitialStates(players: players.shuffled(), existingDone: existingDone)
        var history = History()
        for m in existingDone where m.status == .done {
            recordMatch(m, into: &history)
        }

        var result = existingDone.filter { $0.status == .done }
        var matchIndex = 0
        let maxRounds = players.count * target + players.count

        while states.contains(where: { $0.matchCount < target }), matchIndex < maxRounds {
            let matchNo = startingMatchNo + matchIndex
            guard let picked = pickMatch(
                states: states,
                mode: mode,
                matchIndex: matchNo,
                history: history,
                target: target,
                randomness: randomness
            ) else {
                break
            }

            let courtNo = ((matchNo - 1) % max(1, courtCount)) + 1
            let match = GeneratedMatch(
                matchNo: matchNo,
                courtNo: courtNo,
                team1: picked.team1,
                team2: picked.team2
            )
            result.append(match)
            applyMatch(match, states: &states, matchIndex: matchNo)
            recordMatch(match, into: &history)
            matchIndex += 1
        }

        let sorted = result.sorted { $0.matchNo < $1.matchNo }
        return MatchRoundHelper.assignRounds(
            to: sorted,
            playerIds: players.map(\.id)
        )
    }

    static func regenerateScheduled(
        players: [SessionPlayer],
        mode: GenerationMode,
        matchPerPlayer: Int,
        courtCount: Int,
        lockedMatches: [GeneratedMatch]
    ) -> [GeneratedMatch] {
        let locked = lockedMatches
            .filter { $0.status != .cancelled }
            .sorted { $0.matchNo < $1.matchNo }

        guard players.count >= 4 else { return locked }

        let target = max(1, matchPerPlayer)
        let nextNo = (locked.map(\.matchNo).max() ?? 0) + 1
        let randomness = GenerationRandomness(players: players)
        var states = buildInitialStates(players: players.shuffled(), existingDone: locked)
        var history = History()
        for m in locked {
            recordMatch(m, into: &history)
        }

        var result = locked
        var matchIndex = 0
        let maxRounds = players.count * target + players.count

        while states.contains(where: { $0.matchCount < target }), matchIndex < maxRounds {
            let matchNo = nextNo + matchIndex
            guard let picked = pickMatch(
                states: states,
                mode: mode,
                matchIndex: matchNo,
                history: history,
                target: target,
                randomness: randomness
            ) else {
                break
            }

            let courtNo = ((matchNo - 1) % max(1, courtCount)) + 1
            let match = GeneratedMatch(
                matchNo: matchNo,
                courtNo: courtNo,
                team1: picked.team1,
                team2: picked.team2
            )
            result.append(match)
            applyMatch(match, states: &states, matchIndex: matchNo)
            recordMatch(match, into: &history)
            matchIndex += 1
        }

        return MatchRoundHelper.assignRounds(
            to: result.sorted { $0.matchNo < $1.matchNo },
            playerIds: players.map(\.id)
        )
    }

    // MARK: - Initial state

    private static func buildInitialStates(
        players: [SessionPlayer],
        existingDone: [GeneratedMatch]
    ) -> [PlayerState] {
        players.map { p in
            var s = PlayerState(player: p)
            for m in existingDone where m.status == .done && m.playerIds.contains(p.id) {
                s.matchCount += 1
                s.lastMatchIndex = max(s.lastMatchIndex ?? 0, m.matchNo)
            }
            return s
        }
    }

    // MARK: - Match picking

    private static func pickMatch(
        states: [PlayerState],
        mode: GenerationMode,
        matchIndex: Int,
        history: History,
        target: Int,
        randomness: GenerationRandomness
    ) -> (team1: [UUID], team2: [UUID])? {
        var pool = candidatePool(states: states, target: target, randomness: randomness)
        guard pool.count >= 4 else { return nil }
        pool.shuffle()

        var bestScore: Int?
        var tiedBest: [(team1: [UUID], team2: [UUID])] = []

        for quartet in combinations(pool, choose: 4) {
            for (t1, t2) in teamSplits(for: quartet) {
                let score = scoreMatch(
                    team1: t1,
                    team2: t2,
                    states: states,
                    mode: mode,
                    matchIndex: matchIndex,
                    history: history,
                    target: target
                )
                if bestScore == nil || score < bestScore! {
                    bestScore = score
                    tiedBest = [(t1, t2)]
                } else if score == bestScore {
                    tiedBest.append((t1, t2))
                }
            }
        }

        guard let pick = tiedBest.randomElement() else { return nil }
        return (pick.team1, pick.team2)
    }

    /// 次の試合の候補プレイヤー（出場不足・休憩が長い人を優先）
    private static func candidatePool(
        states: [PlayerState],
        target: Int,
        randomness: GenerationRandomness
    ) -> [UUID] {
        let minCount = states.map(\.matchCount).min() ?? 0

        let sorted = states.sorted { a, b in
            let aBelow = a.matchCount < target
            let bBelow = b.matchCount < target
            if aBelow != bBelow { return aBelow && !bBelow }

            if a.matchCount != b.matchCount { return a.matchCount < b.matchCount }

            let aAtMin = a.matchCount == minCount
            let bAtMin = b.matchCount == minCount
            if aAtMin != bAtMin { return aAtMin && !bAtMin }

            if a.consecutiveRests != b.consecutiveRests {
                return a.consecutiveRests > b.consecutiveRests
            }

            return randomness.prefersFirst(a.player.id, b.player.id)
        }

        let belowTarget = sorted.filter { $0.matchCount < target }
        if belowTarget.count >= 4 {
            var ids: [UUID] = []
            let atMin = belowTarget.filter { $0.matchCount == minCount }
            for s in atMin {
                ids.append(s.player.id)
            }
            for s in belowTarget where s.matchCount != minCount {
                if ids.count >= maxCandidatePoolSize { break }
                let id = s.player.id
                if !ids.contains(id) { ids.append(id) }
            }
            return ids
        }

        var ids = belowTarget.map(\.player.id)
        for s in sorted where s.matchCount >= target && ids.count < maxCandidatePoolSize {
            ids.append(s.player.id)
        }
        return ids
    }

    private static func teamSplits(for ids: [UUID]) -> [([UUID], [UUID])] {
        guard ids.count == 4 else { return [] }
        return [
            ([ids[0], ids[1]], [ids[2], ids[3]]),
            ([ids[0], ids[2]], [ids[1], ids[3]]),
            ([ids[0], ids[3]], [ids[1], ids[2]]),
        ]
    }

    private static func scoreMatch(
        team1: [UUID],
        team2: [UUID],
        states: [PlayerState],
        mode: GenerationMode,
        matchIndex: Int,
        history: History,
        target: Int
    ) -> Int {
        var score = 0
        let all = team1 + team2
        let byId = Dictionary(uniqueKeysWithValues: states.map { ($0.player.id, $0) })
        let minCount = states.map(\.matchCount).min() ?? 0
        let maxCount = states.map(\.matchCount).max() ?? 0

        score += levelScore(team1: team1, team2: team2, states: states, mode: mode)

        for id in all {
            guard let s = byId[id] else { continue }

            if s.matchCount >= target {
                score += 50_000
            }

            let deficit = s.matchCount - minCount
            score += deficit * 2_000

            if maxCount > minCount, s.matchCount == maxCount {
                score += 1_500
            }

            if s.lastMatchIndex == matchIndex - 1 {
                score += 300
            }

            if s.consecutiveRests >= 2 {
                score -= 400
            } else if s.consecutiveRests == 0, s.matchCount > minCount {
                score += 200
            }
        }

        let spread = all.map { byId[$0]?.matchCount ?? 0 }.max()! - all.map { byId[$0]?.matchCount ?? 0 }.min()!
        score += spread * 800

        for i in 0..<team1.count {
            for j in (i + 1)..<team1.count {
                score += history.pairCounts[PairKey(team1[i], team1[j]), default: 0] * 120
            }
        }
        for i in 0..<team2.count {
            for j in (i + 1)..<team2.count {
                score += history.pairCounts[PairKey(team2[i], team2[j]), default: 0] * 120
            }
        }
        for a in team1 {
            for b in team2 {
                score += history.opponentCounts[OpponentKey(a, b), default: 0] * 60
            }
        }

        return score
    }

    private static func levelScore(
        team1: [UUID],
        team2: [UUID],
        states: [PlayerState],
        mode: GenerationMode
    ) -> Int {
        func level(of id: UUID) -> PlayerLevel {
            states.first { $0.player.id == id }?.player.level ?? .beginner
        }

        let t1 = team1.map(level(of:))
        let t2 = team2.map(level(of:))
        let all = t1 + t2

        switch mode {
        case .separated:
            let beginners = all.filter { $0 == .beginner }.count
            let experienced = all.filter { $0 == .experienced }.count
            if beginners > 0 && experienced > 0 { return 10_000 }
            return 0

        case .mix:
            func teamPenalty(_ team: [PlayerLevel]) -> Int {
                let b = team.filter { $0 == .beginner }.count
                let e = team.filter { $0 == .experienced }.count
                if b == 1 && e == 1 { return 0 }
                if b == 2 || e == 2 { return 200 }
                return 120
            }

            var score = teamPenalty(t1) + teamPenalty(t2)
            let t1b = t1.filter { $0 == .beginner }.count
            let t1e = t1.filter { $0 == .experienced }.count
            let t2b = t2.filter { $0 == .beginner }.count
            let t2e = t2.filter { $0 == .experienced }.count
            if (t1e == 2 && t2b == 2) || (t1b == 2 && t2e == 2) {
                score += 250
            }
            return score
        }
    }

    // MARK: - State updates

    private static func applyMatch(
        _ match: GeneratedMatch,
        states: inout [PlayerState],
        matchIndex: Int
    ) {
        let playing = Set(match.playerIds)
        for i in states.indices {
            if playing.contains(states[i].player.id) {
                states[i].matchCount += 1
                states[i].lastMatchIndex = matchIndex
                states[i].consecutiveRests = 0
            } else {
                states[i].consecutiveRests += 1
            }
        }
    }

    private static func recordMatch(_ match: GeneratedMatch, into history: inout History) {
        func addPairs(_ team: [UUID]) {
            guard team.count == 2 else { return }
            history.pairCounts[PairKey(team[0], team[1]), default: 0] += 1
        }
        addPairs(match.team1)
        addPairs(match.team2)
        for a in match.team1 {
            for b in match.team2 {
                history.opponentCounts[OpponentKey(a, b), default: 0] += 1
            }
        }
    }

    // MARK: - Combinatorics

    private static func combinations<T>(_ array: [T], choose k: Int) -> [[T]] {
        guard k > 0, array.count >= k else { return [] }
        if k == 1 { return array.map { [$0] } }
        if k == array.count { return [array] }

        var result: [[T]] = []
        for i in 0...(array.count - k) {
            let element = array[i]
            for tail in combinations(Array(array[(i + 1)...]), choose: k - 1) {
                result.append([element] + tail)
            }
        }
        return result
    }
}

import Foundation

struct GeneratedMatch: Identifiable, Hashable {
    let id: UUID
    var matchNo: Int
    var courtNo: Int
    var roundNo: Int
    var team1: [UUID]
    var team2: [UUID]
    var status: MatchStatus
    /// 試合中スロットの手動指定（nil＝自動）
    var progressOverride: MatchProgressOverride?

    var playerIds: [UUID] { team1 + team2 }

    init(
        id: UUID = UUID(),
        matchNo: Int,
        courtNo: Int,
        roundNo: Int = 1,
        team1: [UUID],
        team2: [UUID],
        status: MatchStatus = .scheduled,
        progressOverride: MatchProgressOverride? = nil
    ) {
        self.id = id
        self.matchNo = matchNo
        self.courtNo = courtNo
        self.roundNo = roundNo
        self.team1 = team1
        self.team2 = team2
        self.status = status
        self.progressOverride = progressOverride
    }
}

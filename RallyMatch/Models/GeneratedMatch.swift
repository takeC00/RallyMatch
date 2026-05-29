import Foundation

struct GeneratedMatch: Identifiable, Hashable {
    let id: UUID
    var matchNo: Int
    var courtNo: Int
    var team1: [UUID]
    var team2: [UUID]
    var status: MatchStatus

    var playerIds: [UUID] { team1 + team2 }

    init(
        id: UUID = UUID(),
        matchNo: Int,
        courtNo: Int,
        team1: [UUID],
        team2: [UUID],
        status: MatchStatus = .scheduled
    ) {
        self.id = id
        self.matchNo = matchNo
        self.courtNo = courtNo
        self.team1 = team1
        self.team2 = team2
        self.status = status
    }
}

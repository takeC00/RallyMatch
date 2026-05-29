import SwiftUI

struct MatchSwapSheet: View {
    let match: GeneratedMatch
    let playerId: UUID
    @Bindable var sessionStore: SessionStore
    let onDone: () -> Void

    private var candidates: [SessionPlayer] {
        sessionStore.players.filter { $0.id != playerId }
    }

    var body: some View {
        NavigationStack {
            List(candidates) { player in
                Button(player.name) {
                    swap(to: player.id)
                }
            }
            .navigationTitle("入れ替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { onDone() }
                }
            }
        }
    }

    private func swap(to newId: UUID) {
        sessionStore.swapPlayer(matchId: match.id, from: playerId, to: newId)
        if let updated = sessionStore.matches.first(where: { $0.id == match.id }) {
            Task {
                do {
                    try await sessionStore.syncSingleMatch(updated)
                    sessionStore.clearSyncError()
                } catch {
                    sessionStore.reportSyncError(error)
                }
            }
        }
        onDone()
    }
}

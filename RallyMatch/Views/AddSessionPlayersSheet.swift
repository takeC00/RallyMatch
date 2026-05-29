import SwiftUI
import SwiftData

struct AddSessionPlayersSheet: View {
    @Bindable var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]
    @State private var selectedIds: Set<UUID> = []

    private var circlePlayers: [Player] {
        guard let circleId = sessionStore.circleId else { return [] }
        return allPlayers.filter { $0.circleId == circleId }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List(circlePlayers) { player in
                if sessionStore.players.contains(where: { $0.id == player.id }) {
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text("参加中").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Toggle(isOn: binding(for: player.id)) {
                        Text(player.name)
                    }
                }
            }
            .navigationTitle("途中参加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let added = circlePlayers
                            .filter { selectedIds.contains($0.id) }
                            .map(SessionPlayer.init(from:))
                        sessionStore.addPlayers(added)
                        Task {
                            if let sessionId = sessionStore.sessionId {
                                try? await SessionSyncService.shared.uploadPlayers(
                                    sessionStore.players,
                                    sessionId: sessionId
                                )
                            }
                        }
                        dismiss()
                    }
                    .disabled(selectedIds.isEmpty)
                }
            }
        }
    }

    private func binding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedIds.contains(id) },
            set: { on in
                if on { selectedIds.insert(id) } else { selectedIds.remove(id) }
            }
        )
    }
}

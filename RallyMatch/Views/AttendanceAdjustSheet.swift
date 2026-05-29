import SwiftUI
import SwiftData

struct AttendanceAdjustSheet: View {
    @Bindable var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]
    @State private var errorMessage: String?
    @State private var isSyncing = false

    private var circlePlayers: [Player] {
        guard let circleId = sessionStore.circleId else { return [] }
        return allPlayers.filter { $0.circleId == circleId }.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Section {
                    ForEach(circlePlayers) { player in
                        attendanceRow(for: player)
                    }
                } header: {
                    Text("参加")
                } footer: {
                    Text("オン＝参加、オフ＝早退。試合中の選手はオフにできません。早退後も試合済・試合中の名前は残り、それ以降の試合からは除外されます。")
                }
            }
            .navigationTitle("遅刻 / 早退")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .overlay {
                if isSyncing {
                    ProgressView()
                }
            }
        }
    }

    @ViewBuilder
    private func attendanceRow(for player: Player) -> some View {
        let sessionPlayer = SessionPlayer(from: player)
        let isActive = sessionStore.players.contains(where: { $0.id == player.id })
        let inProgress = sessionStore.isPlayerInProgress(player.id)

        Toggle(isOn: binding(for: sessionPlayer, currentlyActive: isActive)) {
            HStack {
                Text(player.name)
                    .foregroundStyle(levelColor(player.level))
                Spacer()
                if inProgress {
                    Label("試合中", systemImage: "sportscourt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !isActive {
                    Text("不参加")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(inProgress && isActive)
    }

    private func binding(for player: SessionPlayer, currentlyActive: Bool) -> Binding<Bool> {
        Binding(
            get: { currentlyActive },
            set: { active in
                guard active != currentlyActive else { return }
                if let message = sessionStore.setPlayerParticipating(player, active: active) {
                    errorMessage = message
                    return
                }
                errorMessage = nil
                Task { await syncChanges() }
            }
        )
    }

    private func syncChanges() async {
        guard let sessionId = sessionStore.sessionId else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await SessionSyncService.shared.syncSessionRoster(
                activePlayers: sessionStore.players,
                departedPlayers: sessionStore.departedPlayers,
                sessionId: sessionId
            )
            try await sessionStore.syncMatches()
            sessionStore.clearSyncError()
        } catch {
            sessionStore.reportSyncError(error)
        }
    }

    private func levelColor(_ level: PlayerLevel) -> Color {
        level == .experienced ? .red : .blue
    }
}

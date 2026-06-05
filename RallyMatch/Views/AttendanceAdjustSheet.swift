import SwiftUI

struct AttendanceAdjustSheet: View {
    @Bindable var sessionStore: SessionStore
    @Bindable private var roster = CircleRosterRepository.shared
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isSyncing = false

    private var circlePlayers: [RosterPlayer] {
        guard let circleId = sessionStore.circleId else { return [] }
        return roster.players(for: circleId)
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
            .task {
                if let circleId = sessionStore.circleId {
                    await roster.refresh(circleId: circleId)
                }
            }
        }
    }

    @ViewBuilder
    private func attendanceRow(for player: RosterPlayer) -> some View {
        let sessionPlayer = SessionPlayer(from: player)
        let isActive = sessionStore.players.contains(where: { $0.id == player.playerId })
        let inProgress = sessionStore.isPlayerInProgress(player.playerId)

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

import SwiftUI

struct AttendanceAdjustSheet: View {
    @Bindable var sessionStore: SessionStore
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var dayStore = DayParticipantStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?
    @State private var isSyncing = false

    private struct AttendanceRow: Identifiable {
        let player: SessionPlayer
        let isDayParticipant: Bool

        var id: UUID { player.id }
    }

    /// セッション参加者＋遅刻参加候補（今日だけ参加・名簿メンバー）
    private var attendanceRows: [AttendanceRow] {
        guard let circleId = sessionStore.circleId else { return [] }

        _ = dayStore.revision
        var seen = Set<UUID>()
        var rows: [AttendanceRow] = []

        func append(_ player: SessionPlayer, isDayParticipant: Bool) {
            guard seen.insert(player.id).inserted else { return }
            rows.append(AttendanceRow(player: player, isDayParticipant: isDayParticipant))
        }

        for player in sessionStore.allKnownPlayers {
            append(player, isDayParticipant: dayStore.participants(for: circleId).contains { $0.id == player.id })
        }

        for player in dayStore.participants(for: circleId) {
            append(player, isDayParticipant: true)
        }

        for rosterPlayer in roster.players(for: circleId).filter({ !$0.isLegacyDayVisitor }) {
            append(SessionPlayer(from: rosterPlayer), isDayParticipant: false)
        }

        return rows.sorted { $0.player.name.localizedCaseInsensitiveCompare($1.player.name) == .orderedAscending }
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
                    ForEach(attendanceRows) { row in
                        attendanceRow(for: row)
                    }
                } header: {
                    Text("参加")
                } footer: {
                    Text("オン＝参加（遅刻からの復帰含む）、オフ＝休憩または早退。試合中の選手はオフにできません。オフ中も試合済・試合中の名前は残り、それ以降の試合からは除外されます。")
                }
            }
            .navigationTitle("遅刻・早退・休憩")
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
    private func attendanceRow(for row: AttendanceRow) -> some View {
        let player = row.player
        let isActive = sessionStore.players.contains(where: { $0.id == player.id })
        let inProgress = sessionStore.isPlayerInProgress(player.id)
        let wasInSession = sessionStore.allKnownPlayers.contains(where: { $0.id == player.id })

        Toggle(isOn: binding(for: player, currentlyActive: isActive)) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .foregroundStyle(levelColor(player.level))
                    if row.isDayParticipant {
                        Text("今日だけ参加")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                Spacer()
                if inProgress {
                    Label("試合中", systemImage: "sportscourt.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !isActive {
                    Text(wasInSession ? "休憩・早退" : "未参加")
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

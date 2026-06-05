import SwiftUI

struct SessionSetupView: View {
    let circle: CloudCircle
    var sessionStore: SessionStore

    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var dayStore = DayParticipantStore.shared
    @State private var selectedIds: Set<UUID> = []
    @State private var selectedDayIds: Set<UUID> = []
    @Environment(\.dismiss) private var dismiss
    @State private var showAddParticipant = false
    @State private var isGenerating = false
    @State private var showGenerationHelp = false
    @State private var showParticipantHelp = false

    /// サークルメンバー（registered + manual）。旧 Visitor データは除外
    private var dayParticipants: [SessionPlayer] {
        _ = dayStore.revision
        return dayStore.participants(for: circle.id)
    }

    private var persistentPlayers: [RosterPlayer] {
        roster.players(for: circle.id).filter { !$0.isLegacyDayVisitor }
    }

    private var allSelectedPlayers: [SessionPlayer] {
        let fromRoster = persistentPlayers
            .filter { selectedIds.contains($0.playerId) }
            .map(SessionPlayer.init(from:))
        let fromDay = dayParticipants
            .filter { selectedDayIds.contains($0.id) }
        return fromRoster + fromDay
    }

    private var generationIssues: [GenerationValidation.Issue] {
        GenerationValidation.validate(
            players: allSelectedPlayers,
            mode: sessionStore.mode,
            matchPerPlayer: sessionStore.matchPerPlayer,
            courtCount: sessionStore.courtCount
        )
    }

    private var hasBlockingGenerationIssue: Bool {
        generationIssues.contains { $0.severity == .blocking }
    }

    private var totalSelectedCount: Int {
        allSelectedPlayers.count
    }

    private var canGenerate: Bool {
        totalSelectedCount >= 4
            && !isGenerating
            && !hasBlockingGenerationIssue
            && firebase.isPlistConfigured
            && firebase.isLoggedIn
    }

    private var statusMessage: String {
        if totalSelectedCount < 4 {
            return "当日参加者を4名以上選択してください（現在 \(totalSelectedCount) 名）"
        }
        if let blocking = generationIssues.first(where: { $0.severity == .blocking }) {
            return blocking.message
        }
        if !firebase.isPlistConfigured {
            return "GoogleService-Info.plist が未設定です（Firebase の設定を確認）"
        }
        if !firebase.isLoggedIn {
            return "ログインしてください（RallyMate と同じアカウントで利用できます）"
        }
        return "試合を生成してクラウドに保存します"
    }

    var body: some View {
        @Bindable var store = sessionStore

        Form {
            Section {
                if persistentPlayers.isEmpty && membersRepo.members(for: circle.id).isEmpty {
                    Text("サークルメンバーがいません。下のボタンから手動登録するか、Hub / Mate で招待コード参加してください。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(persistentPlayers) { player in
                    Toggle(isOn: binding(for: player.playerId)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                if player.isManualMember {
                                    Text("手動登録")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(player.level.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(dayParticipants) { participant in
                    Toggle(isOn: dayBinding(for: participant.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(participant.name)
                                Text("今日だけ参加")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            Text(participant.level.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("参加者を追加") { showAddParticipant = true }
            } header: {
                ParticipantSectionHeader(showHelp: $showParticipantHelp, title: "当日参加者")
            }

            Section {
                Picker("生成モード", selection: $store.mode) {
                    ForEach(GenerationMode.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                BlueValueStepperRow(
                    title: "1人あたり試合数",
                    value: $store.matchPerPlayer,
                    range: 1...20
                )
                BlueValueStepperRow(
                    title: "コート数",
                    value: $store.courtCount,
                    range: 1...20
                )
            } header: {
                GenerationConditionsSectionHeader(showHelp: $showGenerationHelp)
            }

            if !generationIssues.isEmpty {
                Section {
                    ForEach(generationIssues) { issue in
                        Label {
                            Text(issue.message)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: issue.severity == .blocking ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(issue.severity == .blocking ? .red : .orange)
                    }
                } header: {
                    Text("生成前の確認")
                }
            }

            if let err = sessionStore.errorMessage {
                Section {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(sessionStore.isQuotaLimited ? .orange : .red)
                } header: {
                    Text(sessionStore.isQuotaLimited ? "クラウド連携を一時停止中" : "エラー")
                }
            }

            Section {
                Button {
                    Task { await prepareAndGenerate() }
                } label: {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("生成・同期中…")
                        }
                    } else {
                        Text("試合を生成")
                    }
                }
                .disabled(!canGenerate)
            } footer: {
                Text(statusMessage)
                    .foregroundStyle(
                        canGenerate
                        ? Color.secondary
                        : (hasBlockingGenerationIssue ? Color.red : Color.orange)
                    )
            }
        }
        .navigationTitle("試合設定")
        .navigationDestination(isPresented: $showGenerationHelp) {
            GenerationSettingsHelpView()
        }
        .navigationDestination(isPresented: $showParticipantHelp) {
            VisitorHelpView()
        }
        .sheet(isPresented: $showAddParticipant) {
            if let uid = firebase.uid {
                ParticipantAddSheet(circle: circle, createdBy: uid)
            }
        }
        .task {
            await reloadMembers()
        }
        .onAppear {
            sessionStore.circleId = circle.id
            if sessionStore.matches.isEmpty {
                _ = sessionStore.expireIfNeeded()
            }
            syncDefaultSelection()
            syncDefaultDaySelection()
        }
        .onChange(of: persistentPlayers.map(\.playerId)) { _, _ in
            syncDefaultSelection()
        }
        .onChange(of: dayParticipants.map(\.id)) { _, _ in
            syncDefaultDaySelection()
        }
        .rallyDarkFormScreen()
    }

    private func reloadMembers() async {
        await membersRepo.refresh(circleId: circle.id)
        do {
            try await membersRepo.syncMembersToRoster(circleId: circle.id)
        } catch {
            membersRepo.lastError = error.localizedDescription
        }
        await roster.refresh(circleId: circle.id)
    }

    private func syncDefaultSelection() {
        if selectedIds.isEmpty, !persistentPlayers.isEmpty {
            selectedIds = Set(persistentPlayers.map(\.playerId))
        }
    }

    private func syncDefaultDaySelection() {
        let ids = Set(dayParticipants.map(\.id))
        guard !ids.isEmpty else {
            selectedDayIds = []
            return
        }
        if selectedDayIds.isEmpty {
            selectedDayIds = ids
        } else {
            let newIds = ids.subtracting(selectedDayIds)
            selectedDayIds.formUnion(newIds)
            selectedDayIds = selectedDayIds.intersection(ids)
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

    private func dayBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedDayIds.contains(id) },
            set: { on in
                if on { selectedDayIds.insert(id) } else { selectedDayIds.remove(id) }
            }
        )
    }

    private func prepareAndGenerate() async {
        isGenerating = true
        sessionStore.isCreatingSession = true
        defer {
            isGenerating = false
            sessionStore.isCreatingSession = false
        }

        guard firebase.isLoggedIn, firebase.uid != nil else {
            sessionStore.errorMessage = "ログインしてください。"
            return
        }

        sessionStore.clearSyncError()
        sessionStore.players = allSelectedPlayers
        sessionStore.circleId = circle.id
        sessionStore.sessionId = AppConfig.stableSessionId(for: circle.id)
        sessionStore.expiresAt = AppConfig.defaultExpiresAt()
        sessionStore.generateMatches()

        guard !sessionStore.matches.isEmpty else {
            sessionStore.errorMessage = "試合を生成できませんでした。参加者が4名以上いるか確認してください。"
            return
        }

        guard let uid = firebase.uid else { return }
        do {
            if let previousId = CircleSessionPreferences.activeSessionId(for: circle.id),
               previousId != sessionStore.sessionId {
                do {
                    try await SessionSyncService.shared.deleteSession(sessionId: previousId)
                } catch {
                    // 自動削除済み・権限なしなどは新規作成を妨げない
                }
            }
            try await sessionStore.syncCreate(ownerUid: uid)
            CircleSessionPreferences.setActiveSessionId(sessionStore.sessionId, for: circle.id)
            sessionStore.errorMessage = nil
            dismiss()
        } catch {
            sessionStore.reportSyncError(error)
        }
    }
}

private struct ParticipantSectionHeader: View {
    @Binding var showHelp: Bool
    var title: String

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(title)
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("参加者の説明")
        }
        .textCase(nil)
    }
}

private struct GenerationConditionsSectionHeader: View {
    @Binding var showHelp: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            Text("生成条件")
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)
        }
        .textCase(nil)
    }
}

private struct BlueValueStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(title)
            Text("\(value)")
                .font(.body.weight(.semibold))
                .foregroundStyle(.blue)
            Spacer()
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
    }
}

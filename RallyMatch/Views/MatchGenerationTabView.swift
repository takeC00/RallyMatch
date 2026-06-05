import SwiftUI

struct MatchGenerationTabView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Bindable private var firebase = FirebaseManager.shared
    @Bindable private var roster = CircleRosterRepository.shared
    @Bindable private var membersRepo = CircleMembersRepository.shared
    @State private var showNewSessionConfirm = false
    @State private var isEndingSession = false

    private var hasActiveSession: Bool {
        sessionStore.sessionId != nil && !sessionStore.matches.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasActiveSession {
                    MatchListView(
                        sessionStore: sessionStore,
                        onRequestNewSession: { showNewSessionConfirm = true },
                        isEndingSession: isEndingSession
                    )
                } else if firebase.isLoadingCircles && firebase.joinedCircles.isEmpty {
                    ProgressView("サークル読み込み中...")
                } else if firebase.joinedCircles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "sportscourt",
                        description: Text("Circle タブでサークルを作成または参加してください")
                    )
                } else {
                    List(firebase.joinedCircles) { circle in
                        NavigationLink {
                            SessionSetupView(circle: circle, sessionStore: sessionStore)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(circle.name)
                                        .font(.headline)
                                    Text("\(playerCount(for: circle)) 名登録")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if playerCount(for: circle) < 4 {
                                    Text("4名以上必要")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .disabled(playerCount(for: circle) < 4)
                    }
                }
            }
            .navigationTitle(hasActiveSession ? "試合一覧" : "試合生成")
            .confirmationDialog(
                "新しい試合を作成しますか？",
                isPresented: $showNewSessionConfirm,
                titleVisibility: .visible
            ) {
                Button("破棄して新規作成", role: .destructive) {
                    Task { await endCurrentSessionAndReset() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("進行中の試合はクラウドからも削除され、元に戻せません。他サークルの QR や試合データには影響しません。")
            }
            .refreshable {
                await firebase.refreshCircles()
                await syncAllMemberRosters()
            }
            .task {
                await firebase.refreshCircles()
                await syncAllMemberRosters()
            }
            .onAppear {
                clearExpiredSessionIfNeeded()
            }
            .rallyDarkScreenBackground()
            .rallyDarkNavigationBar()
        }
    }

    private func clearExpiredSessionIfNeeded() {
        guard let circleId = sessionStore.expireIfNeeded() else { return }
        if CircleSessionPreferences.activeSessionId(for: circleId) != nil {
            CircleSessionPreferences.setActiveSessionId(nil, for: circleId)
        }
    }

    private func playerCount(for circle: CloudCircle) -> Int {
        let memberCount = membersRepo.members(for: circle.id).count
        if memberCount > 0 {
            return memberCount
        }
        return roster.players(for: circle.id).filter { !$0.isLegacyDayVisitor }.count
    }

    private func syncAllMemberRosters() async {
        let circleIds = firebase.joinedCircles.map(\.id)
        await membersRepo.refreshAll(circleIds: circleIds)
        await membersRepo.syncAllJoinedCircles(circleIds)
        await roster.refreshAll(circleIds: circleIds)
    }

    private func endCurrentSessionAndReset() async {
        isEndingSession = true
        defer { isEndingSession = false }

        let sessionId = sessionStore.sessionId
        let circleId = sessionStore.circleId

        if let sessionId {
            do {
                try await SessionSyncService.shared.deleteSession(sessionId: sessionId)
            } catch {
                sessionStore.reportSyncError(error, context: "クラウドの試合削除に失敗しました")
                return
            }
        }

        if let circleId,
           CircleSessionPreferences.activeSessionId(for: circleId) == sessionId {
            CircleSessionPreferences.setActiveSessionId(nil, for: circleId)
        }

        sessionStore.reset()
    }
}

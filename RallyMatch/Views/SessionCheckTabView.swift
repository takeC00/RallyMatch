import SwiftUI

/// 出場回数・ペア・次試合まで（旧「設定」タブの代わり）
struct SessionCheckTabView: View {
    @Environment(SessionStore.self) private var sessionStore

    private var hasActiveSession: Bool {
        sessionStore.sessionId != nil && !sessionStore.matches.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if hasActiveSession {
                    List {
                        NavigationLink {
                            PlayerParticipationView(sessionStore: sessionStore)
                        } label: {
                            Label("出場", systemImage: "person.3.sequence")
                        }
                        NavigationLink {
                            PairCombinationView(sessionStore: sessionStore)
                        } label: {
                            Label("ペア", systemImage: "person.2.circle")
                        }
                        NavigationLink {
                            PlayerNextMatchWaitView(sessionStore: sessionStore)
                        } label: {
                            Label("待ち", systemImage: "clock.arrow.circlepath")
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "試合がありません",
                        systemImage: "chart.bar",
                        description: Text("試合生成タブで試合を作成してください")
                    )
                }
            }
            .navigationTitle("確認")
        }
    }
}

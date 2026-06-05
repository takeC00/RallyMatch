import SwiftUI

struct MainTabView: View {
    @Bindable private var firebase = FirebaseManager.shared
    @State private var sessionStore = SessionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            MembersTabView()
                .tabItem {
                    Label("メンバー登録", systemImage: "person.2")
                }

            MatchGenerationTabView()
                .tabItem {
                    Label("試合生成", systemImage: "sportscourt")
                }

            SessionCheckTabView()
                .tabItem {
                    Label("確認", systemImage: "chart.bar")
                }
        }
        .environment(sessionStore)
        .task {
            clearExpiredSessionIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                clearExpiredSessionIfNeeded()
            }
        }
        .overlay(alignment: .bottom) {
            if let err = firebase.lastError {
                Text("Firebase: \(err)")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.bottom, 56)
                    .padding(.horizontal)
            }
        }
    }

    private func clearExpiredSessionIfNeeded() {
        guard let circleId = sessionStore.expireIfNeeded() else { return }
        if CircleSessionPreferences.activeSessionId(for: circleId) != nil {
            CircleSessionPreferences.setActiveSessionId(nil, for: circleId)
        }
    }
}

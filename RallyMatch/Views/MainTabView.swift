import SwiftUI
import SwiftData

struct MainTabView: View {
    @Bindable private var firebase = FirebaseManager.shared
    @State private var sessionStore = SessionStore()

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

            NavigationStack {
                SettingsView(showsDismissButtons: false)
            }
            .tabItem {
                Label("設定", systemImage: "gearshape")
            }
        }
        .environment(sessionStore)
        .task {
            await firebase.signInAnonymouslyIfNeeded()
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
}

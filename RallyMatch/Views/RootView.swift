import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Circle.createdAt) private var circles: [Circle]
    @Bindable private var firebase = FirebaseManager.shared
    @State private var sessionStore = SessionStore()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if circles.isEmpty {
                    ContentUnavailableView(
                        "サークルがありません",
                        systemImage: "person.3",
                        description: Text("右下の＋からサークルを作成してください")
                    )
                } else {
                    List(circles) { circle in
                        NavigationLink {
                            CircleDetailView(circle: circle, sessionStore: sessionStore)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(circle.name)
                                    .font(.headline)
                                Text("\(circle.players.count) 名登録")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("サークル")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        CircleFormView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
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
                        .padding()
                }
            }
        }
        .environment(sessionStore)
    }
}

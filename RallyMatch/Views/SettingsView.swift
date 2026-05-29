import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared
    @State private var hostingURL = AppConfig.hostingBaseURL

    var showsDismissButtons: Bool = true

    var body: some View {
        Form {
            Section {
                Label(
                    firebase.isPlistConfigured ? "設定済み" : "未設定",
                    systemImage: firebase.isPlistConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(firebase.isPlistConfigured ? .green : .orange)

                if !firebase.isPlistConfigured {
                    Text("Firebase Console から GoogleService-Info.plist をダウンロードし、RallyMatch/ フォルダに配置してから再ビルドしてください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !firebase.isReady {
                    Button("Firebase に再接続") {
                        Task { await firebase.signInAnonymouslyIfNeeded() }
                    }
                }

                if let err = firebase.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Firebase")
            }

            Section {
                TextField("https://your-project.web.app", text: $hostingURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
            } header: {
                Text("参加者用 URL（Firebase Hosting）")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("QRコードは {URL}/session/{sessionId} 形式で生成されます")
                    Text("推奨: \(AppFirebaseConfig.defaultHostingURL)")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("設定")
        .toolbar {
            if showsDismissButtons {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
        .onAppear {
            hostingURL = AppConfig.hostingBaseURL
        }
    }

    private func save() {
        AppConfig.hostingBaseURL = hostingURL
    }
}

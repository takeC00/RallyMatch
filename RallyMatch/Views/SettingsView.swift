import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    var showsDismissButtons: Bool = true

    private var hostingURL: String {
        AppConfig.hostingBaseURL
    }

    var body: some View {
        Form {
            Section {
                if firebase.isLoggedIn {
                    if !firebase.currentUserName.isEmpty {
                        LabeledContent("表示名", value: firebase.currentUserName)
                    }
                    if let email = firebase.currentUserEmail {
                        LabeledContent("メール", value: email)
                    }
                }

                Label(
                    firebase.isPlistConfigured ? "設定済み" : "未設定",
                    systemImage: firebase.isPlistConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(firebase.isPlistConfigured ? .green : .orange)

                if !firebase.isPlistConfigured {
                    Text("Firebase Console から GoogleService-Info.plist をダウンロードし、RallyMatch/ フォルダに配置してから再ビルドしてください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = firebase.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("アカウント / Firebase")
            }

            if firebase.isLoggedIn {
                Section {
                    Button("ログアウト", role: .destructive) {
                        firebase.logout()
                    }
                }
            }

            Section {
                LabeledContent("参加者用 URL") {
                    Text(hostingURL)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("QRコード")
            } footer: {
                Text("QRコードは {URL}/session/{サークルID} 形式で生成されます。サークルごとに URL が異なり、同一サークル内では再生成しても変わりません。")
            }
        }
        .navigationTitle("設定")
        .toolbar {
            if showsDismissButtons {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

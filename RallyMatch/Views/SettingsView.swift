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
                LabeledContent("参加者用 URL") {
                    Text(hostingURL)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("QRコード")
            } footer: {
                Text("QRコードは {URL}/session/{sessionId} 形式で生成されます。URLは Firebase プロジェクトから自動設定されます。")
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

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    var showsDismissButtons: Bool = true

    @State private var displayName = ""
    @State private var isSaving = false
    @State private var profileError = ""
    @State private var didSaveProfile = false

    private var hostingURL: String {
        AppConfig.hostingBaseURL
    }

    private var canSaveProfile: Bool {
        firebase.isLoggedIn
            && !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    var body: some View {
        Form {
            if firebase.isLoggedIn {
                Section {
                    TextField("表示名", text: $displayName)
                        .textInputAutocapitalization(.words)

                    if let email = firebase.currentUserEmail {
                        LabeledContent("メール", value: email)
                    }

                    Button {
                        Task { await saveProfile() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("表示名を保存")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSaveProfile)

                    if !profileError.isEmpty {
                        Text(profileError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if didSaveProfile {
                        Text("保存しました")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } header: {
                    Text("プロフィール")
                } footer: {
                    Text("RallyHub・RallyMate と共通の表示名です。サークルメンバー一覧にも反映されます。")
                }
            }

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
                }

                if let err = firebase.lastError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Firebase")
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
        .onAppear {
            displayName = firebase.currentUserName
        }
        .toolbar {
            if showsDismissButtons {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        profileError = ""
        didSaveProfile = false
        defer { isSaving = false }

        do {
            try await firebase.updateDisplayName(displayName)
            didSaveProfile = true
        } catch {
            profileError = error.localizedDescription
        }
    }
}

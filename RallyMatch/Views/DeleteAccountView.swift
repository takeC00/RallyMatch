import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    @State private var confirmationText = ""
    @State private var password = ""
    @State private var isDeleting = false
    @State private var message: String?

    private var canDelete: Bool {
        confirmationText == "DELETE" && !isDeleting
    }

    var body: some View {
        Form {
            Section {
                Text("この操作は元に戻せません。アカウント（Firebase Auth）を削除し、Firestore 上の自分のユーザーデータと所属情報を削除します。")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Section("再認証（必要な場合）") {
                SecureField("パスワード（メール/パスワードログインの場合）", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section("確認") {
                TextField("DELETE と入力", text: $confirmationText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await runDelete() }
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("アカウントを削除する")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canDelete)
            }
        }
        .navigationTitle("アカウント削除")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
    }

    private func runDelete() async {
        message = nil
        isDeleting = true
        defer { isDeleting = false }

        let pass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await firebase.deleteMyAccount(password: pass.isEmpty ? nil : pass)
            confirmationText = ""
            password = ""
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

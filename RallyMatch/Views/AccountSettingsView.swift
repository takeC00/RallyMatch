import SwiftUI

struct AccountSettingsView: View {
    @Bindable private var firebase = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var showsDismissButton = false

    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var didSave = false
    @State private var showLogoutConfirm = false

    private var canSave: Bool {
        firebase.isLoggedIn
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    var body: some View {
        Form {
            Section {
                TextField("表示名", text: $name)
                    .textInputAutocapitalization(.words)

                if let email = firebase.currentUserEmail {
                    LabeledContent("メール", value: email)
                }
            } header: {
                Text("プロフィール")
            } footer: {
                Text("表示名はサークルメンバー一覧などに表示されます。RallyHub・RallyMate と共通です。")
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if didSave {
                Section {
                    Text("保存しました")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!canSave)
            }

            Section {
                Button("ログアウト", role: .destructive) {
                    showLogoutConfirm = true
                }
            }

            Section {
                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("アカウントを削除")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("アカウントを削除すると、Firebase Auth と Firestore 上の自分のデータが削除されます。この操作は元に戻せません。")
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .onAppear {
            name = firebase.currentUserName
        }
        .confirmationDialog(
            "ログアウトしますか？",
            isPresented: $showLogoutConfirm,
            titleVisibility: .visible
        ) {
            Button("ログアウト", role: .destructive) {
                firebase.logout()
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のアカウントからログアウトします。")
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = ""
        didSave = false
        defer { isSaving = false }

        do {
            try await firebase.updateDisplayName(name)
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AccountToolbarMenu: View {
    @Bindable private var firebase = FirebaseManager.shared
    @Binding var showAccountSettings: Bool

    var body: some View {
        Menu {
            if !firebase.currentUserName.isEmpty {
                Text(firebase.currentUserName)
            }
            if let email = firebase.currentUserEmail {
                Text(email)
                    .font(.caption)
            }

            Button {
                showAccountSettings = true
            } label: {
                Label("アカウント", systemImage: "person.crop.circle")
            }
        } label: {
            Image(systemName: "gearshape")
                .foregroundStyle(.white)
        }
        .accessibilityLabel("アカウント")
    }
}

extension View {
    func accountSettingsSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            NavigationStack {
                AccountSettingsView(showsDismissButton: true)
            }
            .rallyDarkFormScreen()
        }
    }

    func accountToolbar(
        showAccountSettings: Binding<Bool>,
        placement: ToolbarItemPlacement = .topBarTrailing
    ) -> some View {
        toolbar {
            ToolbarItem(placement: placement) {
                AccountToolbarMenu(showAccountSettings: showAccountSettings)
            }
        }
    }
}

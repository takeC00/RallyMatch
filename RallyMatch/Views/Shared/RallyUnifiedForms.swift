import SwiftUI

struct RallySignUpFormView: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    @Binding var showPassword: Bool
    @Binding var errorMessage: String

    let isLoading: Bool
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        Form {
            Section("アカウント") {
                TextField("表示名", text: $name)
                    .textInputAutocapitalization(.words)

                TextField("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                HStack {
                    Group {
                        if showPassword {
                            TextField("パスワード", text: $password)
                        } else {
                            SecureField("パスワード", text: $password)
                        }
                    }
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: onSubmit) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("アカウント作成")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isEnabled)
            }
        }
        .navigationTitle("新規登録")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
    }
}

struct RallyCircleCreateFormView: View {
    @Binding var name: String
    @Binding var sportName: String
    @Binding var description: String
    @Binding var location: String
    @Binding var errorMessage: String

    let isLoading: Bool
    let isEnabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        Form {
            Section("サークル情報") {
                TextField("サークル名", text: $name)

                Picker("競技", selection: $sportName) {
                    ForEach(RallySportOptions.all, id: \.self) { sport in
                        Text(sport).tag(sport)
                    }
                }

                TextField("説明", text: $description, axis: .vertical)
                    .lineLimit(3...6)

                TextField("主な活動場所", text: $location)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: onSubmit) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("サークルを作成")
                                .fontWeight(.bold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isEnabled)
            }
        }
        .navigationTitle("サークル作成")
        .navigationBarTitleDisplayMode(.inline)
        .rallyDarkFormScreen()
    }
}

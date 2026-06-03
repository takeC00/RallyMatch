import SwiftUI

struct RegisterView: View {

    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var isRegisterEnabled: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        ZStack {
            Image("login_bg")
                .resizable()
                .scaledToFill()
                .frame(
                    width: UIScreen.main.bounds.width,
                    height: UIScreen.main.bounds.height
                )
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.15),
                    Color.black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer()
                        .frame(height: 120)

                    VStack(spacing: 16) {
                        authField(icon: "person", fieldBackgroundOpacity: 0.84) {
                            TextField("表示名", text: $name)
                                .foregroundColor(.black)
                        }

                        authField(icon: "envelope", fieldBackgroundOpacity: 0.84) {
                            TextField("メールアドレス", text: $email)
                                .foregroundColor(.black)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                        }

                        authField(icon: "lock", fieldBackgroundOpacity: 0.84) {
                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("パスワード", text: $password)
                                            .foregroundColor(.black)
                                    } else {
                                        SecureField("パスワード", text: $password)
                                            .foregroundColor(.black)
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.black)
                                }
                            }
                        }

                        if !errorMessage.isEmpty {
                            authErrorBanner(errorMessage)
                        }

                        Button {
                            hideKeyboard()
                            errorMessage = ""
                            isLoading = true

                            firebase.signUp(email: email, password: password, name: name) { result in
                                isLoading = false
                                switch result {
                                case .success:
                                    dismiss()
                                case .failure(let error):
                                    errorMessage = FirebaseManager.signUpErrorMessage(for: error)
                                }
                            }
                        } label: {
                            authPrimaryButtonLabel(
                                title: isLoading ? "登録中..." : "アカウント作成",
                                systemImage: "person.crop.circle.badge.plus",
                                isLoading: isLoading,
                                isEnabled: isRegisterEnabled
                            )
                        }
                        .disabled(!isRegisterEnabled)
                    }
                    .padding(.horizontal, 28)

                    Spacer()
                        .frame(height: 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
    }
}

// MARK: - ログイン / 登録フォーム共通（LoginView と共有）

func authField<Content: View>(
    icon: String,
    fieldBackgroundOpacity: Double = 0.72,
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon)
            .foregroundColor(.black)
        content()
    }
    .padding()
    .background(Color.white.opacity(fieldBackgroundOpacity))
    .cornerRadius(18)
}

func authErrorBanner(_ message: String) -> some View {
    HStack(spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
        Text(message)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
        Spacer()
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 14)
    .background(
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.45))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14)
            .stroke(Color.red.opacity(0.65), lineWidth: 1)
    )
}

func authPrimaryButtonLabel(
    title: String,
    systemImage: String,
    isLoading: Bool,
    isEnabled: Bool
) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                isEnabled
                ? LinearGradient(
                    colors: [Color.orange, Color.red.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                : LinearGradient(
                    colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.55)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Image(systemName: systemImage)
                    .font(.headline)
            }
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
    }
    .frame(height: 58)
    .shadow(color: .orange.opacity(0.35), radius: 10)
}

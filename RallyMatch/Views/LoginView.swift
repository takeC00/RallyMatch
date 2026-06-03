import SwiftUI

struct LoginView: View {

    @Bindable private var firebase = FirebaseManager.shared

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var isLoginEnabled: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
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
                            Color.black.opacity(0.45)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()

                    ScrollView {
                        VStack {
                            Spacer(minLength: UIScreen.main.bounds.height * 0.58)

                            Color.clear
                                .frame(height: 1)
                                .id("formAnchor")

                            VStack(spacing: 18) {
                                authField(icon: "envelope") {
                                    TextField("メールアドレス", text: $email)
                                        .foregroundColor(.black)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                }

                                authField(icon: "lock") {
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

                                    firebase.login(email: email, password: password) { result in
                                        isLoading = false
                                        if case .failure(let error) = result {
                                            errorMessage = FirebaseManager.loginErrorMessage(for: error)
                                        }
                                    }
                                } label: {
                                    authPrimaryButtonLabel(
                                        title: isLoading ? "ログイン中..." : "ログイン",
                                        systemImage: "arrow.right.circle.fill",
                                        isLoading: isLoading,
                                        isEnabled: isLoginEnabled
                                    )
                                }
                                .disabled(!isLoginEnabled)

                                NavigationLink {
                                    RegisterView()
                                } label: {
                                    Text("アカウントを作成する 〉")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 10)
                            }
                            .padding(.horizontal, 28)

                            Spacer()
                                .frame(height: 240)
                        }
                    }
                }
                .onChange(of: email) { _, _ in
                    scrollIfNeeded(proxy: proxy)
                }
                .onChange(of: password) { _, _ in
                    scrollIfNeeded(proxy: proxy)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private func scrollIfNeeded(proxy: ScrollViewProxy) {
        guard !email.isEmpty, !password.isEmpty else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("formAnchor", anchor: .top)
            }
        }
    }
}

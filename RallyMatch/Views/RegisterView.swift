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
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.isEmpty
            && !password.isEmpty
            && !isLoading
    }

    var body: some View {
        RallySignUpFormView(
            name: $name,
            email: $email,
            password: $password,
            showPassword: $showPassword,
            errorMessage: $errorMessage,
            isLoading: isLoading,
            isEnabled: isRegisterEnabled,
            onSubmit: signUp
        )
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("閉じる") { dismiss() }
            }
        }
    }

    private func signUp() {
        hideKeyboard()
        errorMessage = ""
        isLoading = true

        Task { @MainActor in
            do {
                try await firebase.signUp(email: email, password: password, name: name)
                dismiss()
            } catch {
                errorMessage = FirebaseManager.signUpErrorMessage(for: error)
            }
            isLoading = false
        }
    }
}

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

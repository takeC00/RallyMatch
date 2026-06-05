import SwiftUI

struct CircleJoinView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    @State private var circleCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""

    private var isEnabled: Bool {
        !circleCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        Form {
            Section {
                TextField("招待コード（例：ABC123）", text: $circleCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
            } footer: {
                Text("Hub / Mate で作成したサークルの招待コードでも参加できます")
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if !successMessage.isEmpty {
                Section {
                    Text(successMessage)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Button(isLoading ? "参加中..." : "参加する") {
                    join()
                }
                .disabled(!isEnabled)
            }
        }
        .navigationTitle("サークル参加")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func join() {
        isLoading = true
        errorMessage = ""
        successMessage = ""

        firebase.joinCircle(code: circleCode) { result in
            isLoading = false
            switch result {
            case .success:
                successMessage = "サークルに参加しました"
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    dismiss()
                }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

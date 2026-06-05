import SwiftUI

struct CircleFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var firebase = FirebaseManager.shared

    @State private var name = ""
    @State private var sportName = RallySportOptions.defaultSport
    @State private var description = ""
    @State private var location = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var isEnabled: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var body: some View {
        RallyCircleCreateFormView(
            name: $name,
            sportName: $sportName,
            description: $description,
            location: $location,
            errorMessage: $errorMessage,
            isLoading: isLoading,
            isEnabled: isEnabled,
            onSubmit: save
        )
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        isLoading = true
        errorMessage = ""

        firebase.createCircle(
            name: trimmedName,
            sportName: sportName,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { result in
            isLoading = false
            switch result {
            case .success:
                dismiss()
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}

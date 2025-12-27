import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct AddStaffView: View {

    // MARK: - Inputs
    let businessId: String
    let onStaffAdded: () -> Void

    // MARK: - State
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var skillsText = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            Form {

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                Section("Staff Details") {
                    TextField("Name", text: $name)

                    TextField(
                        "Skills (comma separated)",
                        text: $skillsText
                    )
                    .autocapitalization(.sentences)
                }

                Section {
                    Button(isSaving ? "Saving…" : "Save Staff") {
                        saveStaff()
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
            .navigationTitle("Add Staff")
        }
    }

    // MARK: - Save
    private func saveStaff() {
        isSaving = true
        errorMessage = nil

        let skills = skillsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        let staff = Staff(
            name: name,
            skills: skills,
            isActive: true
        )

        do {
            _ = try db
                .collection("businesses")
                .document(businessId)
                .collection("staff")
                .addDocument(from: staff)

            onStaffAdded()
            dismiss()

        } catch {
            errorMessage = "Failed to save staff"
        }

        isSaving = false
    }
}


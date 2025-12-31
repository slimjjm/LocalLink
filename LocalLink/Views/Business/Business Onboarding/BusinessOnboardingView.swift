import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessOnboardingView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var businessName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 24) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Create your business")
                    .font(.largeTitle.bold())

                Text("You can change details later.")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Business name", text: $businessName)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button(isSaving ? "Creating…" : "Create business") {
                createBusiness()
            }
            .buttonStyle(.borderedProminent)
            .disabled(businessName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

            Spacer()
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Firestore

    private func createBusiness() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in."
            return
        }

        isSaving = true
        errorMessage = nil

        let data: [String: Any] = [
            "ownerId": uid,
            "name": businessName.trimmingCharacters(in: .whitespaces),
            "isActive": true,
            "createdAt": FieldValue.serverTimestamp()
        ]

        db.collection("businesses")
            .addDocument(data: data) { error in
                DispatchQueue.main.async {
                    isSaving = false

                    if let error {
                        errorMessage = error.localizedDescription
                    } else {
                        dismiss()
                    }
                }
            }
    }
}

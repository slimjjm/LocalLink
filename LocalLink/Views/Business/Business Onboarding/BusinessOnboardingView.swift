import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessOnboardingView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var businessName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 24) {

            Text("Create your business")
                .font(.largeTitle.bold())

            TextField("Business name", text: $businessName)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button {
                createBusiness()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Create business")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                businessName.trimmingCharacters(in: .whitespaces).isEmpty ||
                isSaving
            )

            Spacer()
        }
        .padding()
    }

    // MARK: - Create Business
    private func createBusiness() {

        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Signing you in… please try again in a moment."
            return
        }

        isSaving = true
        errorMessage = nil

        let data: [String: Any] = [
            "businessName": businessName.trimmingCharacters(in: .whitespaces),
            "ownerId": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "staffSlotsAllowed": 1,
            "staffSlotsPurchased": 0,
            "verified": false
        ]

        db.collection("businesses").addDocument(data: data) { error in
            DispatchQueue.main.async {
                isSaving = false

                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    authManager.setRole(.business)
                    dismiss()
                }
            }
        }
    }
}



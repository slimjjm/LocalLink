import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessOnboardingView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState

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
                    .multilineTextAlignment(.center)
            }

            Button {
                createBusiness()
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Create business")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSaving ||
                businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            Spacer()
        }
        .padding()
        .navigationTitle("Business setup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Create Business (Verified Users Only)

    private func createBusiness() {

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to continue."
            return
        }

        if user.isAnonymous {
            errorMessage = "Please create an account to create a business."
            return
        }

        if !user.isEmailVerified {
            user.sendEmailVerification()
            errorMessage = "Please verify your email before creating a business."
            return
        }

        isSaving = true
        errorMessage = nil

        let data: [String: Any] = [
            "businessName": businessName.trimmingCharacters(in: .whitespacesAndNewlines),
            "ownerId": user.uid,
            "createdAt": FieldValue.serverTimestamp(),

            // Discovery
            "isActive": true,

            // Trust / moderation
            "verified": true,

            // Monetisation
            "staffSlotsAllowed": 1,
            "staffSlotsPurchased": 0
        ]

        db.collection("businesses").addDocument(data: data) { error in
            DispatchQueue.main.async {
                isSaving = false

                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    authManager.setRole(.business)
                    nav.reset()
                    nav.path.append(.businessHome)
                }
            }
        }
    }
}


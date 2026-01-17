import SwiftUI
import FirebaseAuth

struct YourAccountView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var showDeleteConfirm = false
    @State private var showResetAlert = false
    @State private var resetMessage = ""
    @State private var isDeleting = false

    // MARK: - Services
    private let deletionService = AccountDeletionService()

    private var user: User? {
        Auth.auth().currentUser
    }

    var body: some View {
        Form {

            // MARK: - Account Info
            Section(header: Text("Account")) {

                HStack {
                    Text("Email")
                    Spacer()
                    Text(user?.email ?? "Unknown")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Account type")
                    Spacer()
                    Text("Customer / Business")
                        .foregroundColor(.secondary)
                }
            }

            // MARK: - Security
            Section(header: Text("Security")) {
                Button("Reset password") {
                    sendPasswordReset()
                }
            }

            // MARK: - Data
            Section(header: Text("Data")) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete account")
                    }
                }
                .disabled(isDeleting)
            }

            // MARK: - Legal
            Section(header: Text("Legal")) {
                Link(
                    "Privacy Policy",
                    destination: URL(string: "https://locallinkapp.co.uk/privacy")!
                )

                Link(
                    "Terms & Conditions",
                    destination: URL(string: "https://locallinkapp.co.uk/terms")!
                )
            }
        }
        .navigationTitle("Your account")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Password reset alert
        .alert("Password reset", isPresented: $showResetAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetMessage)
        }

        // MARK: - Delete confirmation
        .confirmationDialog(
            "Delete account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Deleting your account removes your login and personal data. " +
                "Past bookings will remain for business records."
            )
        }
    }

    // MARK: - Password Reset
    private func sendPasswordReset() {
        guard let email = user?.email else {
            resetMessage = "No email address found for this account."
            showResetAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error {
                resetMessage = error.localizedDescription
            } else {
                resetMessage = "We’ve sent a password reset email to \(email)."
            }
            showResetAlert = true
        }
    }

    // MARK: - Delete Account
    private func deleteAccount() {
        isDeleting = true

        deletionService.deleteAccount { result in
            DispatchQueue.main.async {
                isDeleting = false

                switch result {
                case .success:
                    // ✅ DO NOTHING
                    // Firebase auth state listener will return user to LoginView

                    break

                case .failure(let error):
                    print("❌ Delete account failed:", error.localizedDescription)
                }
            }
        }
    }
}

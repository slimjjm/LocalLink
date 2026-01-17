import SwiftUI
import FirebaseAuth

struct VerifyEmailView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState

    @State private var isChecking = false
    @State private var message = "Please verify your email to continue."

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            Image(systemName: "envelope.badge")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Verify your email")
                .font(.largeTitle.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button {
                checkVerification()
            } label: {
                if isChecking {
                    ProgressView()
                } else {
                    Text("I've verified my email")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isChecking)

            Button("Resend verification email") {
                resendVerification()
            }
            .font(.subheadline)

            Button("Back to login", role: .destructive) {
                authManager.logout()
                nav.reset()
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Reload + Verify

    private func checkVerification() {
        guard let user = Auth.auth().currentUser else { return }

        isChecking = true
        message = "Checking verification status…"

        user.reload { error in
            DispatchQueue.main.async {
                isChecking = false

                if let error {
                    message = error.localizedDescription
                    return
                }

                if user.isEmailVerified {
                    message = "Email verified! Redirecting…"
                } else {
                    message = "Email not verified yet. Please check your inbox."
                }
            }
        }
    }

    private func resendVerification() {
        Auth.auth().currentUser?.sendEmailVerification()
    }
}

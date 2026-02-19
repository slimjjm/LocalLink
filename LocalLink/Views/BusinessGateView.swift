import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessGateView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var showAuthCTA = false
    @State private var showResendVerify = false

    // 🔑 Prevents the gate from re-running every time the view appears
    @State private var hasChecked = false

    private let db = Firestore.firestore()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading business…")

            } else if let errorMessage {
                errorView(message: errorMessage)

            } else {
                // Safety fallback (normally we immediately route away)
                EmptyBusinessStateView()
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Only run the gate once per session entry
            if !hasChecked {
                hasChecked = true
                loadBusiness()
            }
        }
    }

    // MARK: - Error / Gate View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text(message)
                .multilineTextAlignment(.center)

            if let infoMessage {
                Text(infoMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if showResendVerify {
                Button("Resend verification email") {
                    resendVerification()
                }
                .buttonStyle(.bordered)
            }

            if showAuthCTA {
                Button("Log in or Create account") {
                    goToLogin()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Retry") {
                loadBusiness()
            }
            .buttonStyle(.bordered)

            Button("Switch to Customer") {
                authManager.setRole(.customer)
                nav.reset()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Load business logic

    private func loadBusiness() {
        errorMessage = nil
        infoMessage = nil
        showAuthCTA = false
        showResendVerify = false
        isLoading = true

        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Please sign in to manage a business."
            showAuthCTA = true
            return
        }

        // Anonymous users must upgrade
        if user.isAnonymous {
            isLoading = false
            errorMessage = "Please create an account to manage a business."
            showAuthCTA = true
            return
        }

        // Must verify email
        if !user.isEmailVerified {
            isLoading = false
            errorMessage = "Please verify your email before managing a business."
            showResendVerify = true
            infoMessage = "After verifying, return here and tap Retry."
            return
        }

        // Auth OK — check for business ownership
        db.collection("businesses")
            .whereField("ownerId", isEqualTo: user.uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    isLoading = false

                    if let error {
                        errorMessage = error.localizedDescription
                        return
                    }

                    // Route once based on result
                    nav.reset()

                    if snapshot?.documents.first != nil {
                        nav.path.append(.businessHome)
                    } else {
                        nav.path.append(.businessOnboarding)
                    }
                }
            }
    }

    // MARK: - Auth actions

    private func goToLogin() {
        authManager.requireFullLogin()
        nav.path.append(.login)
    }

    private func resendVerification() {
        guard let user = Auth.auth().currentUser else { return }
        user.sendEmailVerification()
        infoMessage = "Verification email sent. Check your inbox, then tap Retry."
    }
}

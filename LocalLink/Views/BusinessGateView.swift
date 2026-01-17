import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessGateView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showAuthCTA = false
    @State private var showResendVerify = false
    @State private var infoMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading business…")

            } else if let errorMessage {
                VStack(spacing: 16) {

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.orange)

                    Text(errorMessage)
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
                }
                .padding()

            } else {
                EmptyBusinessStateView()
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBusiness()
        }
    }

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

        if user.isAnonymous {
            isLoading = false
            errorMessage = "Please create an account to manage a business."
            showAuthCTA = true
            return
        }

        if !user.isEmailVerified {
            isLoading = false
            errorMessage = "Please verify your email before managing a business."
            showResendVerify = true
            infoMessage = "After verifying, return here and tap Retry."
            return
        }

        // ✅ Verified business user — proceed
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

                    nav.reset()
                    if snapshot?.documents.first != nil {
                        nav.path.append(.businessHome)
                    } else {
                        nav.path.append(.businessOnboarding)
                    }
                }
            }
    }

    private func goToLogin() {
        // Prevent the app immediately creating a new anonymous user after sign out
        authManager.requireFullLogin()
        nav.path.append(.login)
    }

    private func resendVerification() {
        guard let user = Auth.auth().currentUser else { return }
        user.sendEmailVerification()
        infoMessage = "Verification email sent. Please check your inbox, then tap Retry."
    }
}

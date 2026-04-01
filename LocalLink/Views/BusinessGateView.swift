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
    @State private var hasChecked = false

    private let db = Firestore.firestore()

    var body: some View {

        VStack {
            
            if isLoading {
                ProgressView("Loading business…")
            }
            else if let errorMessage {
                errorView(message: errorMessage)
            }
            else {
                ProgressView()
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !hasChecked {
                hasChecked = true
                loadBusiness()
            }
        }
    }
}

// MARK: - UI

private extension BusinessGateView {

    func errorView(message: String) -> some View {
        VStack(spacing: 24) {

            Spacer()

            Image(systemName: "briefcase.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primary)

            Text("Start your business")
                .font(.title2.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if let infoMessage {
                Text(infoMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // ✅ SIGN IN CTA (for guest / logged out)
            if showAuthCTA {
                Button {
                    goToAuth()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
            }

            // ✅ EMAIL VERIFY CTA
            if showResendVerify {
                Button("Resend verification email") {
                    resendVerification()
                }
            }

            Button("Retry") {
                loadBusiness()
            }

            Spacer()

            // ✅ SWITCH BACK TO CUSTOMER
            Button {
                authManager.setRole(.customer)
                nav.reset()
                nav.path.append(.customerHome)
            } label: {
                Text("Switch to customer")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

// MARK: - Actions

private extension BusinessGateView {

    func goToAuth() {
        authManager.requireFullLogin()
        nav.path.append(.authEntry)
    }

    func resendVerification() {
        Auth.auth().currentUser?.sendEmailVerification()
        infoMessage = "Verification email sent."
    }
}

// MARK: - Logic

private extension BusinessGateView {

    func loadBusiness() {

        errorMessage = nil
        infoMessage = nil
        showAuthCTA = false
        showResendVerify = false
        isLoading = true

        guard let user = Auth.auth().currentUser else {
            isLoading = false
            errorMessage = "Create an account to start your business on LocalLink."
            showAuthCTA = true
            return
        }

        // ✅ FIXED: Guest flow handled cleanly
        if user.isAnonymous {
            isLoading = false
            errorMessage = "You need an account to create a business."
            showAuthCTA = true
            return
        }

        // ✅ Email verification check
        if !user.isEmailVerified {
            isLoading = false
            errorMessage = "Please verify your email before managing a business."
            showResendVerify = true
            return
        }

        // ✅ Check if business exists
        db.collection("businesses")
            .whereField("ownerId", isEqualTo: user.uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in

                DispatchQueue.main.async {

                    if let error {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                        return
                    }

                    if snapshot?.documents.first != nil {
                        nav.reset()
                        nav.path.append(.businessHome)
                    } else {
                        nav.reset()
                        nav.path.append(.businessOnboarding)
                    }

                    isLoading = false
                }
            }
    }
}

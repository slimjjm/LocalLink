import SwiftUI
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

struct LoginView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var showRegister = false

    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?

    // Apple
    @State private var currentNonce: String?

    // Reset
    @State private var showResetPrompt = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 22) {

            Spacer()

            Text("Log In")
                .font(.largeTitle.bold())

            // MARK: - APPLE SIGN IN

            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = sha256(nonce)
                },
                onCompletion: handleAppleLogin
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(12)

            // MARK: - GOOGLE SIGN IN

            Button {
                handleGoogleLogin()
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.15))
                )
            }

            Text("or")
                .font(.footnote)
                .foregroundColor(.secondary)

            // MARK: - EMAIL / PASSWORD

            VStack(spacing: 14) {

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                Button("Forgot password?") {
                    resetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    showResetPrompt = true
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let localError {
                Text(localError)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let authErr = authManager.errorMessage {
                Text(authErr)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                loginTapped()
            } label: {
                if authManager.isLoading {
                    ProgressView()
                } else {
                    Text("Log in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authManager.isLoading)

            Button("Create an account") {
                showRegister = true
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding()
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRegister) {
            RegisterView()
        }
        .alert("Reset password", isPresented: $showResetPrompt) {
            TextField("Email address", text: $resetEmail)
            Button("Send reset link") { sendPasswordReset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("We’ll email you a link to reset your password.")
        }
        .alert("Password reset", isPresented: $showResetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetMessage)
        }
    }

    // MARK: - EMAIL LOGIN

    private func loginTapped() {
        localError = nil
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty else { localError = "Please enter your email."; return }
        guard !password.isEmpty else { localError = "Please enter your password."; return }

        authManager.login(email: e, password: password) { success in
            if success {
                dismiss()
            }
        }
    }

    // MARK: - GOOGLE LOGIN

    private func handleGoogleLogin() {
        guard
            let clientID = FirebaseApp.app()?.options.clientID,
            let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
                .first
        else {
            localError = "Unable to start Google sign in."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            if let error {
                localError = error.localizedDescription
                return
            }

            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else {
                localError = "Google authentication failed."
                return
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    localError = error.localizedDescription
                    return
                }

                dismiss()
            }
        }
    }

    // MARK: - APPLE LOGIN

    private func handleAppleLogin(_ result: Result<ASAuthorization, Error>) {
        switch result {

        case .success(let authResults):
            guard
                let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let identityToken = appleIDCredential.identityToken,
                let tokenString = String(data: identityToken, encoding: .utf8)
            else {
                localError = "Unable to fetch Apple identity token."
                return
            }

            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: tokenString,
                rawNonce: nonce
            )

            Auth.auth().signIn(with: credential) { _, error in
                if let error {
                    localError = error.localizedDescription
                    return
                }
                dismiss()
            }

        case .failure(let error):
            localError = error.localizedDescription
        }
    }

    // MARK: - NONCE HELPERS

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }

            randoms.forEach { random in
                if remaining == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - RESET PASSWORD

    private func sendPasswordReset() {
        let e = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty else {
            resetMessage = "Please enter your email address."
            showResetAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: e) { error in
            resetMessage = error?.localizedDescription ?? "We’ve sent a reset email to \(e)."
            showResetAlert = true
        }
    }
}


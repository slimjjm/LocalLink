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

    @State private var currentNonce: String?

    @State private var showResetPrompt = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    @State private var showResetAlert = false

    var body: some View {

        ScrollView {

            VStack(spacing: 22) {

                Spacer(minLength: 40)

                // HEADER

                VStack(spacing: 12) {

                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)

                    Text("LocalLink")
                        .font(.title.bold())

                }

                // APPLE LOGIN

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

                // GOOGLE LOGIN

                Button {
                    handleGoogleLogin()
                } label: {

                    HStack {
                        Image(systemName: "g.circle.fill")

                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
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

                // EMAIL

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

                Button("Create an account") {
                    showRegister = true
                }

                Spacer(minLength: 20)

            }
            .padding()

        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRegister) {
            RegisterView()
        }
        .alert("Reset password", isPresented: $showResetPrompt) {

            TextField("Email address", text: $resetEmail)

            Button("Send reset link") {
                sendPasswordReset()
            }

            Button("Cancel", role: .cancel) {}

        } message: {
            Text("We’ll email you a link to reset your password.")
        }
        .alert("Password reset", isPresented: $showResetAlert) {

            Button("OK", role: .cancel) {}

        } message: {
            Text(resetMessage)
        }
    }

    // EMAIL LOGIN

    private func loginTapped() {

        localError = nil

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !e.isEmpty else {
            localError = "Please enter your email."
            return
        }

        guard !password.isEmpty else {
            localError = "Please enter your password."
            return
        }

        authManager.login(email: e, password: password) { success in
            if success {
                dismiss()
            }
        }
    }

    // GOOGLE LOGIN

    private func handleGoogleLogin() {

        authManager.signInWithGoogle()

        dismiss()
    }

    // APPLE LOGIN

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

    // NONCE

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

    // PASSWORD RESET

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

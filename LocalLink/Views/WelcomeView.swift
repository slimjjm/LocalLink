import SwiftUI
import AuthenticationServices
import CryptoKit

struct WelcomeView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 28) {

                Spacer()

                logoSection

                Spacer()

                VStack(spacing: 14) {

                    // MARK: - Apple Sign In
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
                    .disabled(authManager.isLoading)
                    
                    

                    // MARK: - Google Sign In
                    Button {
                        guard !authManager.isLoading else { return }
                        authManager.signInWithGoogle { success in
                            if success {
                                nav.path.append(.customerHome)
                            }
                        }
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
                    .disabled(authManager.isLoading)

                    divider

                    // MARK: - Email (NEW FLOW ENTRY)
                    Button {
                        nav.path.append(.authEntry)
                    } label: {
                        fullWidthButton(
                            title: "Continue with email",
                            background: .blue,
                            foreground: .white
                        )
                    }
                    .disabled(authManager.isLoading)

                    // MARK: - Guest
                    Button {
                        guard !authManager.isLoading else { return }

                        authManager.signInAnonymously { success in
                            if success {
                                nav.path.append(.customerHome)
                            }
                        }
                    } label: {
                        fullWidthButton(
                            title: "Continue as guest",
                            background: Color(.secondarySystemBackground),
                            foreground: .primary
                        )
                    }
                    .disabled(authManager.isLoading)
                }

                // MARK: - Error Message
                if let error = authManager.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Apple Handler

    private func handleAppleLogin(_ result: Result<ASAuthorization, Error>) {
        switch result {

        case .success(let authResults):

            guard
                let credential = authResults.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else { return }

            authManager.signInWithApple(
                idTokenString: token,
                rawNonce: nonce
            ) { success in
                if success {
                    nav.path.append(.customerHome)
                }
            }

        case .failure(let error):
            print("Apple login error:", error.localizedDescription)
        }
    }

    // MARK: - UI Components

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.blue.opacity(0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var logoSection: some View {
        VStack(spacing: 14) {

            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)

            Text("LocalLink")
                .font(.largeTitle.bold())

            Text("Book trusted local services with ease")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var divider: some View {
        HStack {
            Rectangle().frame(height: 1).opacity(0.3)
            Text("or").font(.caption)
            Rectangle().frame(height: 1).opacity(0.3)
        }
    }

    private func fullWidthButton(
        title: String,
        background: Color,
        foreground: Color
    ) -> some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(14)
    }

    // MARK: - Apple Helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {

            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                return random
            }

            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
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
}

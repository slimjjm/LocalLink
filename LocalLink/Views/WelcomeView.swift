import SwiftUI
import AuthenticationServices

struct WelcomeView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        ZStack {
            backgroundGradient

            VStack(spacing: 32) {
                Spacer()
                logoSection
                Spacer()
                buttonStack
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 30)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Background
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

    // MARK: - Logo
    private var logoSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .foregroundColor(.blue)

            Text("LocalLink")
                .font(.largeTitle.bold())
        }
    }

    // MARK: - Buttons
    private var buttonStack: some View {
        VStack(spacing: 14) {

            // Apple Sign In
            SignInWithAppleButton(
                .signIn,
                onRequest: { _ in },
                onCompletion: { _ in
                    nav.path.append(.login)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .cornerRadius(14)

            // Google Sign In
            Button {
                print("Google Sign In tapped")
                authManager.signInWithGoogle()
            } label: {
                fullWidthButton(
                    title: "Continue with Google",
                    background: .white,
                    foreground: .black,
                    border: true
                )
            }

            divider

            // Login
            Button {
                nav.path.append(.login)
            } label: {
                fullWidthButton(
                    title: "Log in",
                    background: Color(.secondarySystemBackground),
                    foreground: .primary
                )
            }

            // Register
            Button {
                nav.path.append(.register)
            } label: {
                fullWidthButton(
                    title: "Create account",
                    background: .blue,
                    foreground: .white
                )
            }

            // Guest
            Button {
                authManager.signInAnonymously()
              
            } label: {
                fullWidthButton(
                    title: "Continue as guest",
                    background: Color(.secondarySystemBackground),
                    foreground: .primary
                )
            }
        }
    }

    // MARK: - Divider
    private var divider: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))

            Text("or")
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3))
        }
        .padding(.vertical, 6)
    }

    // MARK: - Button Style
    private func fullWidthButton(
        title: String,
        background: Color,
        foreground: Color,
        border: Bool = false
    ) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(border ? 0.15 : 0), lineWidth: 1)
            )
    }
}


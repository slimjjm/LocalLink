import SwiftUI
import FirebaseAuth

struct StartSelectionView: View {

    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState

    @State private var resendMessage: String?

    var body: some View {
        VStack(spacing: 28) {

            emailVerificationBanner
            header

            VStack(spacing: 16) {

                // ✅ CREATE ACCOUNT (NEW USERS)
                Button {
                    nav.path.append(.register)
                } label: {
                    selectionCard(
                        icon: "person.crop.circle.badge.plus",
                        title: "Create an account",
                        subtitle: "Sign up to book services or manage a business"
                    )
                }

                // ✅ LOG IN (EXISTING USERS)
                Button {
                    nav.path.append(.login)
                } label: {
                    selectionCard(
                        icon: "person.crop.circle",
                        title: "Log in",
                        subtitle: "Access your existing account"
                    )
                }

                // CUSTOMER FLOW
                Button {
                    authManager.setRole(.customer)
                    nav.reset()
                    nav.path.append(.customerHome)
                } label: {
                    selectionCard(
                        icon: "person.3.fill",
                        title: "I am a Customer",
                        subtitle: "Find local services and book instantly"
                    )
                }

                // BUSINESS FLOW
                Button {
                    authManager.setRole(.business)
                    nav.reset()
                    nav.path.append(.businessGate)
                } label: {
                    selectionCard(
                        icon: "briefcase.fill",
                        title: "I am a Business",
                        subtitle: "Manage bookings, services, and customers"
                    )
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Email verification banner
    @ViewBuilder
    private var emailVerificationBanner: some View {
        if let user = Auth.auth().currentUser,
           !user.isAnonymous,
           !user.isEmailVerified {

            VStack(spacing: 8) {
                Text("Please verify your email")
                    .font(.headline)

                Text("Some features may be limited until you verify.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Resend verification email") {
                    user.sendEmailVerification()
                    resendMessage = "Verification email sent"
                }
                .font(.caption)

                if let resendMessage {
                    Text(resendMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.15))
            .cornerRadius(12)
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .foregroundColor(.blue)

            Text("Welcome to LocalLink")
                .font(.largeTitle.bold())

            Text("Get started by creating an account or logging in")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Selection Card
    private func selectionCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }
}


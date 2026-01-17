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

                // ✅ Always available
                Button {
                    nav.path.append(.login)
                } label: {
                    Text("Log in / Create account")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 6)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

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

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .foregroundColor(.blue)

            Text("Welcome to LocalLink")
                .font(.largeTitle.bold())

            Text("How can we help you today?")
                .foregroundColor(.secondary)
        }
    }

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

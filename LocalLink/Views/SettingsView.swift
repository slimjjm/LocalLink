import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var isDeleting = false
    @State private var deleteError: String?

    // MARK: - Role Check

    private var isBusinessUser: Bool {
        authManager.role == .business
    }

    // MARK: - Body

    var body: some View {

        List {

            // Business Section
            if isBusinessUser {
                businessSection
            }

            // Support Section
            supportSection

            // Account Section
            accountSection

            // Sign Out Section
            signOutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .overlay {
            if isDeleting {
                ProgressView("Deleting account...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Business Section

    private var businessSection: some View {

        Section("Business") {
            NavigationLink {
                StripeConnectView()
            } label: {
                Label("Connect Stripe", systemImage: "creditcard.circle")
            }
            NavigationLink {
                BusinessSubscriptionResolverView()
            } label: {
                Label("Subscription", systemImage: "creditcard")
                    .foregroundColor(AppColors.primary)
            }
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {

        Section("Support") {

            NavigationLink {
                YourAccountView()
            } label: {
                Label("Your account", systemImage: "person.circle")
            }

            Link(
                destination: URL(string: "https://locallinkapp.co.uk/privacy")!
            ) {
                Label("Privacy Policy", systemImage: "lock.shield")
            }

            Link(
                destination: URL(string: "https://locallinkapp.co.uk/terms")!
            ) {
                Label("Terms & Conditions", systemImage: "doc.text")
            }

            Link(
                destination: URL(string: "https://locallinkapp.co.uk/contact")!
            ) {
                Label("Contact us", systemImage: "envelope")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {

        Section("Account") {

            Button(role: .destructive) {
                deleteAccount()
            } label: {
                Label("Delete account", systemImage: "trash")
            }

            if let deleteError {
                Text(deleteError)
                    .foregroundColor(.red)
                    .font(.footnote)
            }
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {

        Section {

            Button(role: .destructive) {

                authManager.logout()
                nav.reset()

            } label: {

                Label("Sign out", systemImage: "arrow.backward.circle.fill")
            }
        }
    }

    // MARK: - Delete Account

    private func deleteAccount() {

        isDeleting = true
        deleteError = nil

        let service = AccountDeletionService()

        service.deleteAccount { result in

            DispatchQueue.main.async {

                isDeleting = false

                switch result {

                case .success:
                    print("✅ Account deleted")

                    authManager.logout()
                    nav.reset()

                case .failure(let error):
                    deleteError = error.localizedDescription
                    print("❌ Delete error:", error.localizedDescription)
                }
            }
        }
    }
}

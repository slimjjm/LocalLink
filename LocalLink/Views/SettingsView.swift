import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

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

            // Sign Out Section
            signOutSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
    }

    // MARK: - Business Section

    private var businessSection: some View {

        Section("Business") {

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
}

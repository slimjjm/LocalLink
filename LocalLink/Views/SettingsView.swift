import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        List {
            supportSection
            signOutSection
        }
        .navigationTitle("Settings")
    }

    // MARK: - Support

    private var supportSection: some View {
        Section("Support") {

            NavigationLink("Your account") {
                YourAccountView()
            }

            Link(
                "Privacy Policy",
                destination: URL(string: "https://locallinkapp.co.uk/privacy")!
            )

            Link(
                "Terms & Conditions",
                destination: URL(string: "https://locallinkapp.co.uk/terms")!
            )

            Link(
                "Contact us",
                destination: URL(string: "https://locallinkapp.co.uk/contact")!
            )
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                authManager.logout()
                nav.reset()
            } label: {
                Label("Sign out", systemImage: "arrow.backward.circle")
            }
        }
    }
}


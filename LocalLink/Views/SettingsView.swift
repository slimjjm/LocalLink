import SwiftUI
import FirebaseAuth

struct SettingsView: View {

    var body: some View {
        List {
            accountSection
            supportSection
            signOutSection
        }
        .navigationTitle("Settings")
    }

    // MARK: - Account (USER level, not business)
    private var accountSection: some View {
        Section("Account") {
            NavigationLink {
                ProfileView()
            } label: {
                Label("Your account", systemImage: "person")
            }
        }
    }

    // MARK: - Support & Legal
    private var supportSection: some View {
        Section("Support") {

            Link(destination: URL(string: "https://locallinkapp.co.uk/privacy")!) {
                Label("Privacy Policy", systemImage: "lock.shield")
            }

            Link(destination: URL(string: "https://locallinkapp.co.uk/terms")!) {
                Label("Terms & Conditions", systemImage: "doc.text")
            }

            Link(destination: URL(string: "https://locallinkapp.co.uk/contact")!) {
                Label("Contact us", systemImage: "envelope")
            }
        }
    }

    // MARK: - Sign out
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                try? Auth.auth().signOut()
            } label: {
                Label("Sign out", systemImage: "arrow.backward.circle")
            }
        }
    }
}

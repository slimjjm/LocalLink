import SwiftUI
import FirebaseAuth

struct YourAccountView: View {

    @State private var email: String = ""

    var body: some View {

        List {

            Section("Account") {

                Label {
                    Text(email.isEmpty ? "Unknown" : email)
                } icon: {
                    Image(systemName: "envelope")
                }
            }

            Section("Information") {

                Text("Account deletion is available in Settings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Your account")
        .onAppear {
            loadAccount()
        }
    }

    private func loadAccount() {

        if let user = Auth.auth().currentUser {
            email = user.email ?? "Anonymous user"
        }
    }
}


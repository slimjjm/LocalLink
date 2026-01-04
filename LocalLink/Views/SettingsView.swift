import SwiftUI
import FirebaseAuth
import UIKit

struct SettingsView: View {

    @AppStorage("userType") private var userType = ""

    var body: some View {
        List {

            // MARK: - Legal
            Section(header: Text("Legal")) {

                settingsLink(
                    title: "Privacy Policy",
                    url: "https://locallinkapp.co.uk/privacy"
                )

                settingsLink(
                    title: "Terms & Conditions",
                    url: "https://locallinkapp.co.uk/terms"
                )
            }

            // MARK: - Support
            Section(header: Text("Support")) {

                Button {
                    openSupportEmail()
                } label: {
                    HStack {
                        Text("Contact Support")
                        Spacer()
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // MARK: - Account
            Section {

                Button(role: .destructive) {
                    logOut()
                } label: {
                    HStack {
                        Text("Log out")
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Helpers

    private func settingsLink(title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func openSupportEmail() {
        let email = "founder@locallinkapp.co.uk"
        let subject = "LocalLink App Support"
        let body = ""

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let mailtoString = "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)"

        if let url = URL(string: mailtoString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func logOut() {
        try? Auth.auth().signOut()
        userType = ""
    }
}


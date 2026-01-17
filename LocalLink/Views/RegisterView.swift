import SwiftUI

struct RegisterView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 18) {

            Spacer()

            Text("Create account")
                .font(.largeTitle.bold())

            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                SecureField("Confirm password", text: $confirm)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

            if let localError {
                Text(localError)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let authErr = authManager.errorMessage {
                Text(authErr)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                signUpTapped()
            } label: {
                if authManager.isLoading {
                    ProgressView()
                } else {
                    Text("Create account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authManager.isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUpTapped() {
        localError = nil

        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty else { localError = "Please enter your email."; return }
        guard password.count >= 6 else { localError = "Password must be at least 6 characters."; return }
        guard password == confirm else { localError = "Passwords do not match."; return }

        authManager.signUp(email: e, password: password) { success in
            if success {
                dismiss()
            }
        }
    }
}

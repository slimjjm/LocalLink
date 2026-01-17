import SwiftUI
import FirebaseAuth

struct LoginView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var showRegister = false

    @State private var email = ""
    @State private var password = ""
    @State private var localError: String?

    // Reset
    @State private var showResetPrompt = false
    @State private var resetEmail = ""
    @State private var resetMessage = ""
    @State private var showResetAlert = false

    var body: some View {
        VStack(spacing: 22) {

            Spacer()

            Text("Welcome back")
                .font(.largeTitle.bold())

            VStack(spacing: 14) {

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                Button("Forgot password?") {
                    resetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    showResetPrompt = true
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                loginTapped()
            } label: {
                if authManager.isLoading {
                    ProgressView()
                } else {
                    Text("Log in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authManager.isLoading)

            Button("Create an account") {
                showRegister = true
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding()
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRegister) {
            RegisterView()
        }
        .alert("Reset password", isPresented: $showResetPrompt) {
            TextField("Email address", text: $resetEmail)
            Button("Send reset link") { sendPasswordReset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("We’ll email you a link to reset your password.")
        }
        .alert("Password reset", isPresented: $showResetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(resetMessage)
        }
    }

    private func loginTapped() {
        localError = nil
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty else { localError = "Please enter your email."; return }
        guard !password.isEmpty else { localError = "Please enter your password."; return }

        authManager.login(email: e, password: password) { success in
            if success {
                // ✅ Close login screen; StartSelection/BusinessGate can continue
                dismiss()
            }
        }
    }

    private func sendPasswordReset() {
        let e = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty else {
            resetMessage = "Please enter your email address."
            showResetAlert = true
            return
        }

        Auth.auth().sendPasswordReset(withEmail: e) { error in
            resetMessage = error?.localizedDescription ?? "We’ve sent a reset email to \(e)."
            showResetAlert = true
        }
    }
}

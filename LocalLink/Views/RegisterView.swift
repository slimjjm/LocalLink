import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var showConfirm = false
    @State private var localError: String?

    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 18) {

            Spacer()

            Text("Create account")
                .font(.largeTitle.bold())

            VStack(spacing: 14) {

                // MARK: - Name
                TextField("Full name", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                // MARK: - Email
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                // MARK: - Password
                HStack {
                    Group {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                    }

                    Button(showPassword ? "Hide" : "Show") {
                        showPassword.toggle()
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

                // MARK: - Confirm Password
                HStack {
                    Group {
                        if showConfirm {
                            TextField("Confirm password", text: $confirm)
                        } else {
                            SecureField("Confirm password", text: $confirm)
                        }
                    }

                    Button(showConfirm ? "Hide" : "Show") {
                        showConfirm.toggle()
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }

            // MARK: - Errors
            if let localError {
                Text(localError)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let authErr = authManager.errorMessage {
                Text(authErr)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // MARK: - Create Account Button
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

    // MARK: - Sign Up Logic

    private func signUpTapped() {
        localError = nil

        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !n.isEmpty else {
            localError = "Please enter your name."
            return
        }

        guard !e.isEmpty else {
            localError = "Please enter your email."
            return
        }

        guard password.count >= 6 else {
            localError = "Password must be at least 6 characters."
            return
        }

        guard password == confirm else {
            localError = "Passwords do not match."
            return
        }

        authManager.signUp(email: e, password: password) { success in
            guard success else { return }

            guard let uid = Auth.auth().currentUser?.uid else { return }

            // 🔥 Save profile to Firestore
            db.collection("users")
                .document(uid)
                .setData([
                    "name": n,
                    "email": e,
                    "createdAt": FieldValue.serverTimestamp()
                ], merge: true)

            dismiss()
        }
    }
}

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showVerificationNotice = false

    var body: some View {
        VStack(spacing: 20) {

            Text("Create Account")
                .font(.largeTitle.bold())
                .padding(.top, 40)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .keyboardType(.emailAddress)
                .padding(.horizontal)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            if showVerificationNotice {
                VStack(spacing: 8) {
                    Text("Check your email 📩")
                        .font(.headline)

                    Text(
                        "We’ve sent a verification link to \(email).\n" +
                        "You can continue using the app, but some features may require verification."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .padding()
            }

            Button {
                print("🟢 Create account button tapped")

                authManager.signUp(email: email, password: password) { success in
                    print("🟢 SignUp completion:", success)
                    if success {
                        showVerificationNotice = true
                    }
                }
            } label: {
                if authManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Create account")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .background(Color.orange)
            .cornerRadius(10)
            .padding(.horizontal)
            .disabled(authManager.isLoading)

            Spacer()
        }
    }
}


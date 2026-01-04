import SwiftUI
import FirebaseAuth

struct LoginView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Text("Login")
                    .font(.largeTitle.bold())

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textFieldStyle(.roundedBorder)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    login()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Log in")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || isLoading)

                Button("Create an account") {
                    showRegister = true
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    // MARK: - Login

    private func login() {
        errorMessage = nil
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

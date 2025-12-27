import SwiftUI
import FirebaseAuth

struct CustomerLoginView: View {

    // MARK: - App State (root routing)
    @AppStorage("userType") private var userType: String = ""

    // MARK: - UI State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var goToRegister: Bool = false

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            // Title
            Text("Customer Login")
                .font(.largeTitle.bold())

            // Email
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            // Password
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Login button
            Button {
                login()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            // Create account
            Button("Create an Account") {
                goToRegister = true
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $goToRegister) {
            CustomerRegisterView()
        }
    }

    // MARK: - Login Logic
    private func login() {
        errorMessage = nil
        isLoading = true

        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isLoading = false

            if let error {
                errorMessage = error.localizedDescription
            } else {
                // 🔑 Root navigation trigger
                userType = "customer"
            }
        }
    }
}

#Preview {
    CustomerLoginView()
}



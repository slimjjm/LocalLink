import SwiftUI
import FirebaseAuth

struct CustomerRegisterView: View {

    // MARK: - Root App State
    @AppStorage("userType") private var userType: String = ""

    // MARK: - Navigation
    @Environment(\.dismiss) private var dismiss

    // MARK: - UI State
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            // Title
            Text("Customer Register")
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
            SecureField("Password (min 6 characters)", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Create Account Button
            Button {
                register()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Create Account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.count < 6)

            Spacer()
        }
        .padding()
    }

    // MARK: - Register Logic
    private func register() {
        errorMessage = nil
        isLoading = true

        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            isLoading = false

            if let error {
                errorMessage = error.localizedDescription
            } else {
                // 🔑 Set root state
                userType = "customer"

                // 🔑 Remove this pushed view so new root is visible
                dismiss()
            }
        }
    }
}

#Preview {
    CustomerRegisterView()
}

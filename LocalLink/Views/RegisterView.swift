import SwiftUI
import FirebaseAuth

struct RegisterView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {

            Text("Create account")
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
                register()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("Create account")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isLoading)

            Spacer()
        }
        .padding()
    }

    // MARK: - Register

    private func register() {
        errorMessage = nil
        isLoading = true

        Auth.auth().createUser(withEmail: email, password: password) { _, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        }
    }
}

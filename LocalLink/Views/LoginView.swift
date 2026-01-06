import SwiftUI
import FirebaseAuth

struct LoginView: View {

    @EnvironmentObject private var nav: NavigationState

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 24) {

            Spacer()

            Text("Welcome back")
                .font(.largeTitle.bold())

            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)

                SecureField("Password", text: $password)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }

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
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Login

    private func login() {
        errorMessage = nil
        isLoading = true

        Auth.auth().signIn(
            withEmail: email.trimmingCharacters(in: .whitespaces),
            password: password
        ) { _, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error {
                    errorMessage = error.localizedDescription
                    return
                }

                // ✅ Single source of truth navigation
                nav.setRoot(.customerHome)
            }
        }
    }
}


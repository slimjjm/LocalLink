import SwiftUI

struct AuthEntryView: View {
    
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState
    
    @State private var email = ""
    @State private var password = ""
    
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            
            Spacer()
            
            // MARK: - Header
            VStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                
                Text("LocalLink")
                    .font(.title.bold())
                
                Text("Continue to LocalLink")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Inputs
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
            }
            
            // MARK: - Error
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // MARK: - CTA
            Button {
                continueTapped()
            } label: {
                
                if authManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isButtonDisabled)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Welcome")
    }
}

//
// MARK: - State
//

private extension AuthEntryView {
    
    var isButtonDisabled: Bool {
        if authManager.isLoading { return true }
        if !email.contains("@") { return true }
        if password.count < 6 { return true }
        return false
    }
}

//
// MARK: - Continue Logic
//

private extension AuthEntryView {
    
    func continueTapped() {
        
        errorMessage = nil
        
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleaned.isEmpty else {
            errorMessage = "Enter your email."
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        // 🔥 Try login FIRST (this feels natural to user)
        authManager.login(email: cleaned, password: password) { success in
            
            DispatchQueue.main.async {
                
                if success {
                    nav.path = [.roleSelection]
                    return
                }
                
                // If login failed → try signup
                if authManager.errorMessage == "No account found for this email" {
                    
                    authManager.signUp(email: cleaned, password: password) { signupSuccess in
                        
                        DispatchQueue.main.async {
                            if signupSuccess {
                                nav.path = [.roleSelection]
                            } else {
                                errorMessage = authManager.errorMessage
                            }
                        }
                    }
                    
                } else {
                    // Wrong password / other error
                    errorMessage = authManager.errorMessage
                }
            }
        }
    }
}

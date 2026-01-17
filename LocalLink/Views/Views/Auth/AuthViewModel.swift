import Foundation
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Register
    
    func signUp(
        email: String,
        password: String,
        completion: @escaping (Bool) -> Void
    ) {
        isLoading = true
        errorMessage = nil
        
        guard let user = Auth.auth().currentUser else {
            self.isLoading = false
            self.errorMessage = "No active user session."
            completion(false)
            return
        }
        
        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        
        user.link(with: credential) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                result?.user.sendEmailVerification { error in
                    if let error {
                        print("❌ VERIFICATION ERROR:", error)
                        self.errorMessage = error.localizedDescription
                        completion(false)
                    } else {
                        print("✅ VERIFICATION EMAIL SENT")
                        completion(true)
                    }
                }

            }
        }
    }
}

import Foundation
import FirebaseAuth
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var user: User? = Auth.auth().currentUser
    @Published var errorMessage: String?

    init() {
        self.user = Auth.auth().currentUser
    }

    // SIGN UP
    func signUp(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                completion(false)
                return
            }
            self.user = result?.user
            completion(true)
        }
    }

    // LOGIN
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                completion(false)
                return
            }
            self.user = result?.user
            completion(true)
        }
    }

    // LOG OUT
    func logout() {
        try? Auth.auth().signOut()
        self.user = nil
    }
}


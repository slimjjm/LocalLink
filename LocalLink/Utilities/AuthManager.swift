import FirebaseAuth
import Combine

final class AuthManager: ObservableObject {

    @Published var isReady = false

    init() {
        if Auth.auth().currentUser != nil {
            // User already signed in (including anonymous)
            isReady = true
        } else {
            // Perform anonymous sign-in once
            Auth.auth().signInAnonymously { _, error in
                DispatchQueue.main.async {
                    self.isReady = (error == nil)
                }
            }
        }
    }
}



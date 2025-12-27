import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct EmailVerificationView: View {

    @State private var isEmailVerified = false
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 20) {
            Text("Verify Your Email")
                .font(.title)

            Text("We’ve sent a verification link to your email.")

            Button("I've Verified") {
                checkEmailVerification()
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            sendEmailVerification()
            startVerificationPolling()
        }
    }

    // Sends verification link
    func sendEmailVerification() {
        Auth.auth().currentUser?.sendEmailVerification()
    }

    // Polls Firebase to check if verified
    func startVerificationPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            checkEmailVerification()
        }
    }

    func checkEmailVerification() {
        Auth.auth().currentUser?.reload()
        if Auth.auth().currentUser?.isEmailVerified == true {
            timer?.invalidate()
            isEmailVerified = true

            let userId = Auth.auth().currentUser!.uid
            Firestore.firestore().collection("users")
                .document(userId)
                .updateData(["emailVerified": true])
        }
    }
}


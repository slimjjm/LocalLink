import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct PhoneVerificationView: View {

    @State private var phone: String = ""
    @State private var codeSent = false
    @State private var verificationID = ""
    @State private var otpCode: String = ""

    var body: some View {
        VStack(spacing: 20) {

            if !codeSent {
                TextField("Phone Number", text: $phone)
                    .textFieldStyle(.roundedBorder)

                Button("Send Code") { sendCode() }
                    .buttonStyle(.borderedProminent)

            } else {
                TextField("Enter Code", text: $otpCode)
                    .textFieldStyle(.roundedBorder)

                Button("Verify Code") { verifyCode() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    func sendCode() {
        PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil) { id, error in
            if let id = id {
                verificationID = id
                codeSent = true
            }
        }
    }

    func verifyCode() {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )

        Auth.auth().currentUser?.link(with: credential) { result, error in
            if error == nil {
                let userId = Auth.auth().currentUser!.uid
                Firestore.firestore().collection("users")
                    .document(userId)
                    .updateData(["phoneVerified": true])
            }
        }
    }
}


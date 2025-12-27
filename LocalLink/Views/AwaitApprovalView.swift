import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AwaitApprovalView: View {

    @State private var isApproved = false

    var body: some View {
        VStack(spacing: 20) {

            if !isApproved {
                ProgressView()
                Text("Your business is being reviewed.")
                Text("We will notify you once approved.")
            }
        }
        .onAppear { pollApprovalStatus() }
    }

    func pollApprovalStatus() {
        let userId = Auth.auth().currentUser!.uid

        Firestore.firestore().collection("users")
            .document(userId)
            .addSnapshotListener { snap, _ in
                if (snap?.get("adminApproved") as? Bool) == true {
                    isApproved = true
                }
            }
    }
}


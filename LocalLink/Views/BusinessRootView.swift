import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessRootView: View {

    @State private var businessId: String?
    @State private var isLoading = true

    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading business…")
                }
                else if let businessId {
                    BusinessHomeView(businessId: businessId)
                }
                else {
                    EmptyBusinessStateView()
                }
            }
            .onAppear {
                loadBusinessId()
            }
        }
    }

    // MARK: - Load Business
    private func loadBusinessId() {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }

        db.collection("businesses")
            .whereField("ownerId", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    businessId = doc.documentID
                }

                isLoading = false
            }
    }
}

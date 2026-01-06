import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class CustomerBusinessListViewModel: ObservableObject {

    @Published var businesses: [Business] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBusinesses() {
        isLoading = true
        errorMessage = nil

        db.collection("businesses")
            .whereField("isActive", isEqualTo: true)
            .whereField("verified", isEqualTo: true)
            .order(by: "createdAt", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                self.businesses = snapshot?.documents.compactMap {
                    try? $0.data(as: Business.self)
                } ?? []
            }
    }
}

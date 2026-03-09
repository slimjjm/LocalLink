import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class CustomerBusinessListViewModel: ObservableObject {

    @Published var businesses: [Business] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBusinesses(town: String? = nil, category: String? = nil) {

        isLoading = true
        errorMessage = nil
        businesses = []

        var query: Query = db.collection("businesses")
            .whereField("isActive", isEqualTo: true)

        if let town, !town.isEmpty {
            query = query.whereField("serviceTowns", arrayContains: town)
        }

        if let category, !category.isEmpty {
            query = query.whereField("category", isEqualTo: category)
        }

        query
            .order(by: "createdAt", descending: true)
            .limit(to: 200)
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.errorMessage = "Failed to load businesses: \(error.localizedDescription)"
                    return
                }

                let results = snapshot?.documents.compactMap { doc in
                    try? doc.data(as: Business.self)
                } ?? []

                self.businesses = results
            }
    }
}

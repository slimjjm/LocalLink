import Foundation
import FirebaseAuth
import FirebaseFirestore

struct OwnedBusinessSummary: Identifiable {
    let id: String            // businessId (document ID)
    let name: String
    let createdAt: Date?
}

@MainActor
final class BusinessResolverViewModel: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""
    @Published var businesses: [OwnedBusinessSummary] = []
    @Published var selectedBusinessId: String? = nil

    private let db = Firestore.firestore()

    func load() {
        isLoading = true
        errorMessage = ""
        businesses = []
        selectedBusinessId = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "You must be logged in."
            return
        }

        db.collection("businesses")
            .whereField("ownerId", isEqualTo: uid)
            .getDocuments { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.isLoading = false
                    self.errorMessage = "Failed to load your business. \(error.localizedDescription)"
                    return
                }

                let docs = snapshot?.documents ?? []

                if docs.isEmpty {
                    self.isLoading = false
                    self.errorMessage = "No business found for this account yet."
                    return
                }

                let mapped: [OwnedBusinessSummary] = docs.map { doc in
                    let data = doc.data()
                    let name = (data["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()

                    return OwnedBusinessSummary(
                        id: doc.documentID,
                        name: (name?.isEmpty == false) ? name! : "Unnamed Business",
                        createdAt: createdAt
                    )
                }

                // V1 behaviour: auto-select a business.
                // Preference: newest first (by createdAt), otherwise stable by name.
                let sorted = mapped.sorted { a, b in
                    switch (a.createdAt, b.createdAt) {
                    case let (da?, db?):
                        return da > db
                    case (nil, nil):
                        return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                    case (nil, _?):
                        return false
                    case (_?, nil):
                        return true
                    }
                }

                self.businesses = sorted
                self.selectedBusinessId = sorted.first?.id
                self.isLoading = false
            }
    }
}

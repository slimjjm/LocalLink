import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class ServiceListViewModel: ObservableObject {

    // MARK: - Published state
    @Published var services: [BusinessService] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Firestore
    private let db = Firestore.firestore()

    func loadServices(for businessId: String, activeOnly: Bool = false) {
        isLoading = true
        errorMessage = nil

        var query: Query = db
            .collection("businesses")
            .document(businessId)
            .collection("services")

        // 🔒 V2 feature – safe to ignore for now
        if activeOnly {
            query = query.whereField("isActive", isEqualTo: true)
        }

        query.getDocuments { [weak self] snapshot, error in
            guard let self else { return }

            self.isLoading = false

            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            self.services = snapshot?.documents.compactMap {
                try? $0.data(as: BusinessService.self)
            } ?? []
        }
    }
}


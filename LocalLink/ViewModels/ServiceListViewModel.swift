import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class ServiceListViewModel: ObservableObject {

    @Published var services: [Service] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadServices(for businessId: String, activeOnly: Bool) {
        isLoading = true
        errorMessage = nil

        var query: Query = db
            .collection("businesses")
            .document(businessId)
            .collection("services")

        if activeOnly {
            query = query.whereField("isActive", isEqualTo: true)
        }

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                self?.services = snapshot?.documents.compactMap {
                    try? $0.data(as: Service.self)
                } ?? []
            }
        }
    }
}

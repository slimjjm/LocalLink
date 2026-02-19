import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessProfileViewModel: ObservableObject {

    // MARK: - Published state
    @Published var business: Business?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()

    // MARK: - Load business profile
    func load(businessId: String) {
        isLoading = true
        errorMessage = ""

        db.collection("businesses")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                guard let self else { return }

                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                do {
                    self.business = try snapshot?.data(as: Business.self)
                } catch {
                    self.errorMessage = "Failed to decode business profile."
                }
            }
    }
}

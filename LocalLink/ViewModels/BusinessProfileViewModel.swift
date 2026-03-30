import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessProfileViewModel: ObservableObject {

    @Published var business: Business?
    @Published var services: [BusinessService] = []
    @Published var nextAvailableSlot: Date?
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""

    private let db = Firestore.firestore()
    private let slotService = NextAvailableSlotService()

    func load(businessId: String) {
        isLoading = true
        errorMessage = ""

        Task {
            do {
                async let businessTask = fetchBusiness(businessId)
                async let servicesTask = fetchServices(businessId)
                async let slotTask = withCheckedContinuation { continuation in
                    slotService.fetchNextSlot(businessId: businessId) { slot in
                        continuation.resume(returning: slot)
                    }
                }

                self.business = try await businessTask
                self.services = try await servicesTask
                self.nextAvailableSlot = try await slotTask

                self.isLoading = false

            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Private fetches

    private func fetchBusiness(_ id: String) async throws -> Business {
        let snapshot = try await db.collection("businesses").document(id).getDocument()
        return try snapshot.data(as: Business.self)
    }

    private func fetchServices(_ businessId: String) async throws -> [BusinessService] {
        let snapshot = try await db
            .collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments()

        return try snapshot.documents.compactMap {
            try $0.data(as: BusinessService.self)
        }
    }
}

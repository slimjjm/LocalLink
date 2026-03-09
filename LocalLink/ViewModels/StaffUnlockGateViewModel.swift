import Foundation
import FirebaseFirestore

@MainActor
final class StaffUnlockGateViewModel: ObservableObject {

    @Published var entitlements = BusinessEntitlements()
    @Published var staffCount: Int = 0              // ✅ active staff count (used seats)
    @Published var totalStaffCount: Int = 0         // ✅ total staff docs (optional but useful)
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let repo = EntitlementsRepository()

    private var entitlementsListener: ListenerRegistration?
    private var staffListener: ListenerRegistration?

    func start(businessId: String) {
        stop()
        isLoading = true
        errorMessage = nil

        // Listen to entitlements (server-controlled)
        entitlementsListener = repo.listenEntitlements(businessId: businessId) { [weak self] result in
            guard let self else { return }

            switch result {
            case .failure(let err):
                self.errorMessage = err.localizedDescription
            case .success(let ent):
                self.entitlements = ent
            }

            self.isLoading = false
        }

        // ✅ Listen to staff docs, but count ACTIVE as "used"
        staffListener = db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .addSnapshotListener { [weak self] snap, err in

                guard let self else { return }

                if let err {
                    self.errorMessage = err.localizedDescription
                    self.isLoading = false
                    return
                }

                let docs = snap?.documents ?? []
                self.totalStaffCount = docs.count

                // active used seats (default true if missing)
                self.staffCount = docs.reduce(0) { partial, doc in
                    let isActive = (doc.data()["isActive"] as? Bool) ?? true
                    return partial + (isActive ? 1 : 0)
                }

                self.isLoading = false
            }
    }

    func stop() {
        entitlementsListener?.remove()
        staffListener?.remove()
        entitlementsListener = nil
        staffListener = nil
    }

    // Seats allowed by plan (free 1 + paid extras)
    var allowedStaff: Int {
        max(1, entitlements.totalAllowedStaff)
    }

    // Can add means: active staff < allowed seats
    var canAddStaff: Bool {
        staffCount < allowedStaff
    }

    var remainingSlots: Int {
        max(0, allowedStaff - staffCount)
    }
}

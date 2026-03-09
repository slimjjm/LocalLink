import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions

final class StaffRepository {

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    // =================================================
    // MARK: - FETCH ALL STAFF (ordered by seatRank)
    // =================================================
    func fetchAllStaff(
        businessId: String,
        completion: @escaping ([Staff]) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .order(by: "seatRank")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ fetchAllStaff error:", error.localizedDescription)
                    completion([])
                    return
                }

                let staff: [Staff] =
                    snapshot?.documents.compactMap { doc in
                        try? doc.data(as: Staff.self)
                    } ?? []

                completion(staff)
            }
    }

    // =================================================
    // MARK: - CREATE STAFF (Server Enforced)
    // =================================================
    func createStaff(
        businessId: String,
        name: String
    ) async throws -> String {

        let result = try await functions
            .httpsCallable("createStaffMember")
            .call([
                "businessId": businessId,
                "name": name
            ])

        guard
            let data = result.data as? [String: Any],
            let staffId = data["staffId"] as? String
        else {
            throw NSError(
                domain: "StaffRepository",
                code: 0,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Invalid server response (missing staffId)."
                ]
            )
        }

        return staffId
    }

    // =================================================
    // MARK: - DELETE STAFF (Server Enforced)
    // =================================================
    func deleteStaff(
        businessId: String,
        staffId: String
    ) async throws {

        _ = try await functions
            .httpsCallable("deleteStaffMember")
            .call([
                "businessId": businessId,
                "staffId": staffId
            ])
    }

    // =================================================
    // MARK: - UPDATE SEAT RANKS (Server Enforced)
    // =================================================
    func updateSeatRanks(
        businessId: String,
        orderedStaff: [Staff]
    ) async throws {

        let ids = orderedStaff.compactMap { $0.id }

        _ = try await functions
            .httpsCallable("updateStaffSeatRanks")
            .call([
                "businessId": businessId,
                "orderedIds": ids
            ])
    }

    // =================================================
    // MARK: - RECONCILE SEATS (Force Re-Enforcement)
    // =================================================
    func reconcileSeatEnforcementNow(
        businessId: String
    ) async {

        do {
            _ = try await functions
                .httpsCallable("reconcileSeatEnforcementNow")
                .call([
                    "businessId": businessId
                ])
        } catch {
            print("⚠️ reconcileSeatEnforcementNow failed:",
                  error.localizedDescription)
        }
    }
}

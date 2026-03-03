

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions

final class StaffRepository {

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    // =================================================
    // FETCH ALL STAFF (ordered by seatRank)
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
    // SERVER-ENFORCED CREATE (Cloud Function)
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
                userInfo: [NSLocalizedDescriptionKey: "Invalid server response (missing staffId)."]
            )
        }

        return staffId
    }

    // =================================================
    // UPDATE SEAT RANKS (persist drag/drop ordering)
    // =================================================
    func updateSeatRanks(
        businessId: String,
        orderedStaff: [Staff]
    ) async throws {

        let batch = db.batch()

        for (index, member) in orderedStaff.enumerated() {
            guard let staffId = member.id, !staffId.isEmpty else { continue }

            let ref = db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)

            batch.updateData(["seatRank": index], forDocument: ref)
        }

        try await batch.commitAsync()
    }

    // =================================================
    // OPTIONAL: Re-apply enforcement after reorder
    // =================================================
    func reconcileSeatEnforcementNow(businessId: String) async {
        do {
            _ = try await functions
                .httpsCallable("reconcileSeatEnforcementNow")
                .call(["businessId": businessId])
        } catch {
            print("⚠️ reconcileSeatEnforcementNow failed:", error.localizedDescription)
        }
    }
}

// =====================================================
// MARK: - WriteBatch async helper (works on all SDKs)
// =====================================================
private extension WriteBatch {
    func commitAsync() async throws {
        try await withCheckedThrowingContinuation { cont in
            self.commit { error in
                if let error = error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
}

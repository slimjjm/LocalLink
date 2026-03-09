import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

final class BlockTimeService {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    // =================================================
    // DEBUG: CHECK CONFLICTING BOOKINGS
    // =================================================
    func checkConflictingBookings(
        businessId: String,
        staffId: String?,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {

        print("👤 Auth UID:", Auth.auth().currentUser?.uid ?? "NIL")
        print("🧪 checkConflictingBookings called")
        print("🧪 businessId:", businessId)
        print("🧪 staffId:", staffId ?? "nil")
        print("🧪 window:", startDate, "→", endDate)

        guard Auth.auth().currentUser != nil else {
            completion(.failure(NSError(
                domain: "BlockTimeService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Auth not ready (currentUser is nil)."]
            )))
            return
        }

        var query: Query = db
            .collection("bookings")
            .whereField("businessId", isEqualTo: businessId)

        if let staffId {
            query = query.whereField("staffId", isEqualTo: staffId)
        }

        // Optional: reduce reads (only confirmed)
        // query = query.whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)

        query.getDocuments { snapshot, error in
            if let error {
                print("❌ conflict query error:", error)
                completion(.failure(error))
                return
            }

            let docs = snapshot?.documents ?? []
            print("🧪 bookings fetched:", docs.count)

            let conflicts = docs.filter { doc in
                guard
                    let startTS = doc["startDate"] as? Timestamp,
                    let endTS = doc["endDate"] as? Timestamp
                else { return false }

                let bookingStart = startTS.dateValue()
                let bookingEnd = endTS.dateValue()

                return bookingStart < endDate && bookingEnd > startDate
            }

            print("🧪 conflicts found:", conflicts.count)
            completion(.success(conflicts.count))
        }
    }

    // =================================================
    // ADD TIME BLOCK (OPTIONAL REPEAT SUPPORT)
    // Writes to: businesses/{businessId}/timeBlocks
    // =================================================
    func addTimeBlock(
        businessId: String,
        staffId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        repeatType: String = "none",      // none | daily | weekly | monthly
        repeatUntil: Date? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        print("👤 Auth UID:", Auth.auth().currentUser?.uid ?? "NIL")
        print("🧪 addTimeBlock called")
        print("🧪 businessId:", businessId)
        print("🧪 staffId:", staffId)
        print("🧪 title:", title)
        print("🧪 range:", startDate, "→", endDate)
        print("🧪 repeatType:", repeatType)
        print("🧪 repeatUntil:", repeatUntil as Any)

        guard endDate > startDate else {
            completion(.failure(NSError(
                domain: "BlockTimeService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "End date must be after start date."]
            )))
            return
        }

        let finalDate = repeatUntil ?? startDate
        var currentStart = startDate
        var currentEnd = endDate

        let batch = db.batch()

        while currentStart <= finalDate {

            let block = TimeBlock(
                staffId: staffId,
                startDate: currentStart,
                endDate: currentEnd,
                title: title
            )

            let ref = db
                .collection("businesses")
                .document(businessId)
                .collection("timeBlocks")
                .document()

            do {
                try batch.setData(from: block, forDocument: ref)
                print("🧪 queued timeBlock doc:", ref.documentID, currentStart, "→", currentEnd)
            } catch {
                completion(.failure(error))
                return
            }

            switch repeatType {
            case "daily":
                currentStart = calendar.date(byAdding: .day, value: 1, to: currentStart)!
                currentEnd = calendar.date(byAdding: .day, value: 1, to: currentEnd)!

            case "weekly":
                currentStart = calendar.date(byAdding: .day, value: 7, to: currentStart)!
                currentEnd = calendar.date(byAdding: .day, value: 7, to: currentEnd)!

            case "monthly":
                currentStart = calendar.date(byAdding: .month, value: 1, to: currentStart)!
                currentEnd = calendar.date(byAdding: .month, value: 1, to: currentEnd)!

            default:
                currentStart = finalDate.addingTimeInterval(1)
            }
        }

        batch.commit { error in
            if let error {
                print("❌ addTimeBlock batch.commit failed:", error)
                completion(.failure(error))
            } else {
                print("✅ addTimeBlock batch.commit success")
                completion(.success(()))
            }
        }
    }

    // =================================================
    // DELETE BLOCK
    // =================================================
    func deleteTimeBlock(
        businessId: String,
        blockId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        db.collection("businesses")
            .document(businessId)
            .collection("timeBlocks")
            .document(blockId)
            .delete { error in
                if let error { completion(.failure(error)) }
                else { completion(.success(())) }
            }
    }
}

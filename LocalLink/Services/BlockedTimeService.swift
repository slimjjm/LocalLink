import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class BlockedTimeService {

    private let db = Firestore.firestore()

    // =========================================
    // CHECK CONFLICTING BOOKINGS
    // =========================================

    func checkConflictingBookings(
        businessId: String,
        staffId: String?,
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        print("🧪 checkConflictingBookings called")
        print("🧪 businessId:", businessId)
        print("🧪 staffId:", staffId ?? "nil")
        print("🧪 window:", startDate, "→", endDate)

        // TEMP: no status filter at all until we confirm the data shape/path
        var query: Query = db
            .collection("bookings")
            .whereField("businessId", isEqualTo: businessId)

        if let staffId {
            query = query.whereField("staffId", isEqualTo: staffId)
        }

        query.getDocuments { snapshot, error in
            if let error {
                print("❌ conflict query error:", error)
                completion(.failure(error))
                return
            }

            guard let docs = snapshot?.documents else {
                print("🧪 conflict query returned nil docs")
                completion(.success(0))
                return
            }

            print("🧪 bookings fetched:", docs.count)

            for d in docs.prefix(10) {
                print("🧪 booking doc id:", d.documentID)
                print("🧪 keys:", Array(d.data().keys).sorted())
                print("🧪 status:", d.data()["status"] ?? "nil")
                print("🧪 startTime:", d.data()["startTime"] ?? "nil")
                print("🧪 endTime:", d.data()["endTime"] ?? "nil")
                print("🧪 date:", d.data()["date"] ?? "nil")
                print("🧪 time:", d.data()["time"] ?? "nil")
            }

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
    // =========================================
    // ADD BLOCK (UNCHANGED)
    // =========================================

    func addBlock(
        businessId: String,
        title: String,
        startDate: Date,
        endDate: Date,
        repeatType: String,
        repeatUntil: Date?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        let calendar = Calendar.current
        let batch = db.batch()

        let finalDate = repeatUntil ?? startDate
        var currentStart = startDate
        var currentEnd = endDate

        while currentStart <= finalDate {

            let block = BlockedTime(
                businessId: businessId,
                staffId: nil,
                title: title,
                startDate: currentStart,
                endDate: currentEnd,
                repeatType: "none",
                repeatUntil: nil,
                createdAt: Date()
            )

            let ref = db
                .collection("businesses")
                .document(businessId)
                .collection("blockedTimes")
                .document()

            do {
                try batch.setData(from: block, forDocument: ref)
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
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class BlockedTimeService {

    private let db = Firestore.firestore()

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

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
        let block = BlockedTime(
            businessId: businessId,
            staffId: nil, // whole business (V2)
            title: title,
            startDate: startDate,
            endDate: endDate,
            repeatType: repeatType,
            repeatUntil: repeatUntil,
            createdAt: Date()
        )

        do {
            _ = try db.collection("blockedTimes").addDocument(from: block)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}

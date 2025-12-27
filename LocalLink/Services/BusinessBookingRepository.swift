import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class BusinessBookingsRepository {

    private let db = Firestore.firestore()

    func fetchBookings(
        businessId: String,
        for date: Date,
        completion: @escaping ([Booking]) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .whereField("status", isEqualTo: "confirmed")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ Failed to fetch bookings:", error.localizedDescription)
                    completion([])
                    return
                }

                let bookings = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                completion(bookings)
            }
    }
}


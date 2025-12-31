import FirebaseFirestore
import FirebaseFirestoreSwift

final class BookingRepository {

    private let db = Firestore.firestore()

    // MARK: - Create

    func createBooking(
        _ booking: Booking,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            _ = try db
                .collection("bookings")
                .addDocument(from: booking)

            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Cancel (Customer)

    func cancelBookingByCustomer(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.cancelledByCustomer.rawValue
            ]) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }

    // MARK: - Cancel (Business)

    func cancelBookingByBusiness(
        bookingId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        db.collection("bookings")
            .document(bookingId)
            .updateData([
                "status": BookingStatus.cancelledByBusiness.rawValue
            ]) { error in
                if let error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
    }
}




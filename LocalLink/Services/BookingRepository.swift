import FirebaseFirestore
import FirebaseFirestoreSwift

final class BookingRepository {

    private let db = Firestore.firestore()

    // MARK: - Create (CORRECT + RELIABLE)

    func createBooking(
        _ booking: Booking,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        let ref = db.collection("bookings").document()

        do {
            try ref.setData(from: booking) { error in
                DispatchQueue.main.async {
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
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
                DispatchQueue.main.async {
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
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
                DispatchQueue.main.async {
                    if let error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
}

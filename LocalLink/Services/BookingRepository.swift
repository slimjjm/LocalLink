import FirebaseFirestore
import FirebaseFirestoreSwift

final class BookingRepository {

    private let db = Firestore.firestore()

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
}


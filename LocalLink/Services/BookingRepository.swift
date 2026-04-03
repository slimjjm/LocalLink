import FirebaseFirestore
import FirebaseFirestoreSwift

final class BookingRepository {

    private let db = Firestore.firestore()

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
}

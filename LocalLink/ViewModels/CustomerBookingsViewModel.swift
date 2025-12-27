import Foundation
import FirebaseFirestore
import FirebaseAuth

final class CustomerBookingsViewModel: ObservableObject {

    @Published var bookings: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBookings() {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not signed in"
            return
        }

        let today = Calendar.current.startOfDay(for: Date())

        isLoading = true
        errorMessage = nil

        db.collection("bookings")
            .whereField("customerId", isEqualTo: userId)
            .whereField("date", isGreaterThanOrEqualTo: today)
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .order(by: "date")
            .getDocuments { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.bookings = snapshot?.documents.compactMap {
                        try? $0.data(as: Booking.self)
                    } ?? []
                }
            }
    }
}


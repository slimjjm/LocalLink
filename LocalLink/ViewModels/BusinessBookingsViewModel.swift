import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessBookingsViewModel: ObservableObject {

    @Published var upcoming: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    func loadBookings(for businessId: String) {
        isLoading = true
        errorMessage = nil

        print("🔍 Loading bookings for businessId:", businessId)

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .order(by: "startDate", descending: false)
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    print("❌ Booking fetch error:", error.localizedDescription)
                    return
                }

                let bookings = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                print("📦 RAW BOOKINGS FOUND:", bookings.count)

                let now = Date()

                self.upcoming = bookings
                    .filter { $0.endDate >= now }
                    .sorted { $0.startDate < $1.startDate }

                print("✅ UPCOMING BOOKINGS:", self.upcoming.count)
            }
    }
}

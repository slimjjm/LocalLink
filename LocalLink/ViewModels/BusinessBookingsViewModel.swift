import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessBookingsViewModel: ObservableObject {

    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []

    @Published var monthlyRevenueEarned: Int = 0
    @Published var monthlyProjectedIncome: Int = 0
    @Published var monthlyRefunds: Int = 0
    @Published var monthlyCompletedCount: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()

    private let db = Firestore.firestore()
    private var currentBusinessId: String?

    // MARK: - Month Label

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    // MARK: - Month Navigation

    func goToNextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = next
            reloadIfNeeded()
        }
    }

    func goToPreviousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = prev
            reloadIfNeeded()
        }
    }

    private func reloadIfNeeded() {
        guard let id = currentBusinessId else { return }
        loadBookings(for: id)
    }

    // MARK: - Load Bookings

    func loadBookings(for businessId: String) {

        currentBusinessId = businessId
        isLoading = true
        errorMessage = nil

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "startDate", descending: false)
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let bookings = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                let now = Date()
                let calendar = Calendar.current

                // ===== Upcoming =====

                self.upcoming = bookings
                    .filter {
                        $0.status == .confirmed &&
                        $0.startDate >= now
                    }
                    .sorted { $0.startDate < $1.startDate }

                // ===== Past =====

                self.past = bookings
                    .filter {
                        $0.status == .completed ||
                        $0.status == .refunded ||
                        $0.status == .cancelledByBusiness ||
                        $0.status == .cancelledByCustomer
                    }
                    .sorted { $0.startDate > $1.startDate }

                // ===== Monthly Stats (Selected Month) =====

                let monthBookings = bookings.filter {
                    calendar.isDate($0.startDate, equalTo: self.selectedMonth, toGranularity: .month)
                }

                let completed = monthBookings.filter { $0.status == .completed }

                let confirmed = monthBookings.filter {
                    $0.status == .confirmed &&
                    $0.startDate >= now
                }

                let refunded = monthBookings.filter { $0.status == .refunded }

                self.monthlyCompletedCount = completed.count

                self.monthlyRevenueEarned =
                    Int(completed.reduce(0.0) { $0 + $1.price * 100 })

                self.monthlyProjectedIncome =
                    Int(confirmed.reduce(0.0) { $0 + $1.price * 100 })

                self.monthlyRefunds =
                    Int(refunded.reduce(0.0) { $0 + $1.price * 100 })
            }
    }
}


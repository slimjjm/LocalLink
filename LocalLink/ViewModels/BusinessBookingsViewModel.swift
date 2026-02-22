import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessBookingsViewModel: ObservableObject {

    @Published var staff: [Staff] = []
    
    // MARK: - Booking Lists
    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []

    // MARK: - Monthly Stats (pence)
    @Published var monthlyRevenueEarned: Int = 0
    @Published var remainingThisMonth: Int = 0
    @Published var monthlyRefunds: Int = 0
    @Published var monthlyCompletedCount: Int = 0
    @Published var percentMonthFilled: Double = 0
    @Published var monthlyProjectedIncome: Int = 0
    @Published var maxPossibleThisMonth: Int = 0

    // MARK: - UI
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    // MARK: - Private
    private let db = Firestore.firestore()
    private var currentBusinessId: String?

    // =================================================
    // MONTH NAVIGATION
    // =================================================
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadCapacityAndProjections(businessId: id)
        }
    }

    // =================================================
    // LOAD BOOKINGS
    // =================================================
    func loadBookings(for businessId: String) {

        currentBusinessId = businessId
        isLoading = true
        errorMessage = nil

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "startDate")
            .getDocuments { [weak self] snapshot, error in

                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                let bookings: [Booking] = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                let cal = Calendar.current
                let today = Date().localMidnight()

                self.upcoming = bookings
                    .filter {
                        $0.status == .confirmed &&
                        (($0.bookingDay ?? $0.startDate.localMidnight()) >= today)
                    }
                    .sorted { $0.startDate < $1.startDate }

                self.past = bookings
                    .filter { $0.status != .confirmed }
                    .sorted { $0.startDate > $1.startDate }

                let monthBookings = bookings.filter {
                    let day = $0.bookingDay ?? $0.startDate.localMidnight()
                    return cal.isDate(day, equalTo: self.selectedMonth, toGranularity: .month)
                }

                let completed = monthBookings.filter { $0.status == .completed }
                let confirmed = monthBookings.filter { $0.status == .confirmed }
                let refunded = monthBookings.filter { $0.status == .refunded }

                self.monthlyCompletedCount = completed.count
                self.monthlyRevenueEarned = completed.reduce(0) { $0 + $1.price }
                self.remainingThisMonth = confirmed.reduce(0) { $0 + $1.price }
                self.monthlyRefunds = refunded.reduce(0) { $0 + $1.price }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.loadCapacityAndProjections(businessId: businessId)
                }
            }
    }
    func loadStaff(for businessId: String) {

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { snapshot, error in

                if let error {
                    print("❌ Failed to load staff:", error)
                    return
                }

                guard let docs = snapshot?.documents else { return }

                self.staff = docs.compactMap {
                    try? $0.data(as: Staff.self)
                }

                print("👥 Staff loaded:", self.staff.count)
            }
    }
    // =================================================
    // CAPACITY + PROJECTION
    // =================================================
    private func loadCapacityAndProjections(businessId: String) {

        let cal = Calendar.current
        guard let range = cal.dateInterval(of: .month, for: selectedMonth) else { return }

        fetchAverageServicePrice(businessId: businessId) { [weak self] avgPrice in
            guard let self else { return }

            self.db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .getDocuments { [weak self] staffSnap, _ in

                    guard let self else { return }

                    let staffIds = staffSnap?.documents.map { $0.documentID } ?? []
                    if staffIds.isEmpty {
                        self.percentMonthFilled = 0
                        self.monthlyProjectedIncome = 0
                        self.maxPossibleThisMonth = 0
                        return
                    }

                    var totalSlots = 0
                    var bookedSlots = 0
                    let group = DispatchGroup()

                    for staffId in staffIds {

                        group.enter()

                        self.db.collection("businesses")
                            .document(businessId)
                            .collection("staff")
                            .document(staffId)
                            .collection("availableSlots")
                            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: range.start))
                            .whereField("startTime", isLessThan: Timestamp(date: range.end))
                            .getDocuments { snap, _ in

                                let docs = snap?.documents ?? []
                                totalSlots += docs.count
                                bookedSlots += docs.filter { ($0["isBooked"] as? Bool) == true }.count
                                group.leave()
                            }
                    }

                    group.notify(queue: .main) {

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {

                            let remainingSlots = max(0, totalSlots - bookedSlots)

                            self.percentMonthFilled =
                                totalSlots > 0
                                ? (Double(bookedSlots) / Double(totalSlots)) * 100
                                : 0

                            guard avgPrice > 0 else {
                                self.monthlyProjectedIncome = 0
                                self.maxPossibleThisMonth = 0
                                return
                            }

                            let avgPricePence = Int((avgPrice * 100).rounded())
                            self.monthlyProjectedIncome = remainingSlots * avgPricePence
                            self.maxPossibleThisMonth = totalSlots * avgPricePence
                        }
                    }
                }
        }
    }

    // =================================================
    // AVG SERVICE PRICE
    // =================================================
    private func fetchAverageServicePrice(
        businessId: String,
        completion: @escaping (Double) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snapshot, _ in

                let prices: [Double] = snapshot?.documents.compactMap {
                    ($0["price"] as? NSNumber)?.doubleValue
                } ?? []

                let avg = prices.isEmpty ? 0 : (prices.reduce(0, +) / Double(prices.count))
                completion(avg)
            }
    }
}

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessBookingsViewModel: ObservableObject {

    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []

    @Published var monthlyRevenueEarned: Int = 0
    @Published var monthlyProjectedIncome: Int = 0     // remaining capacity × avg service price
    @Published var remainingThisMonth: Int = 0         // future confirmed £
    @Published var monthlyRefunds: Int = 0
    @Published var monthlyCompletedCount: Int = 0
    @Published var percentMonthFilled: Double = 0
    @Published var maxPossibleThisMonth: Int = 0       // total capacity × avg service price

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedMonth: Date = Date()

    private let db = Firestore.firestore()
    private var currentBusinessId: String?

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

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

                // Upcoming
                self.upcoming = bookings
                    .filter { $0.status == .confirmed && $0.startDate >= now }
                    .sorted { $0.startDate < $1.startDate }

                // Past
                self.past = bookings
                    .filter {
                        $0.status == .completed ||
                        $0.status == .refunded ||
                        $0.status == .cancelledByBusiness ||
                        $0.status == .cancelledByCustomer
                    }
                    .sorted { $0.startDate > $1.startDate }

                // Month subset
                let monthBookings = bookings.filter {
                    calendar.isDate($0.startDate, equalTo: self.selectedMonth, toGranularity: .month)
                }

                let completed = monthBookings.filter { $0.status == .completed }
                let confirmed = monthBookings.filter { $0.status == .confirmed }
                let futureConfirmed = confirmed.filter { $0.startDate >= now }
                let refunded = monthBookings.filter { $0.status == .refunded }

                self.monthlyCompletedCount = completed.count

                self.monthlyRevenueEarned =
                    Int(completed.reduce(0.0) { $0 + $1.price * 100 })

                self.remainingThisMonth =
                    Int(futureConfirmed.reduce(0.0) { $0 + $1.price * 100 })

                self.monthlyRefunds =
                    Int(refunded.reduce(0.0) { $0 + $1.price * 100 })

                // Capacity + projections
                self.loadCapacityAndProjections(
                    businessId: businessId,
                    monthBookings: monthBookings
                )
            }
    }

    // MARK: - Capacity (slots) + Projection (avg service price)

    private func loadCapacityAndProjections(
        businessId: String,
        monthBookings: [Booking]
    ) {
        let calendar = Calendar.current
        guard let monthRange = calendar.dateInterval(of: .month, for: selectedMonth) else { return }

        // 1) Fetch average price from services (so projections work even with 0 bookings)
        fetchAverageServicePrice(businessId: businessId) { [weak self] avgServicePrice in
            guard let self else { return }

            // Fallback: if services have no prices, use bookings avg if available
            let fallbackAvgFromBookings: Double = {
                guard !monthBookings.isEmpty else { return 0 }
                return monthBookings.map { $0.price }.reduce(0, +) / Double(monthBookings.count)
            }()

            let avgPrice = avgServicePrice > 0 ? avgServicePrice : fallbackAvgFromBookings

            // 2) Count totalSlots + bookedSlots from availableSlots
            self.db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .getDocuments { staffSnap, _ in

                    let staffIds = staffSnap?.documents.map { $0.documentID } ?? []
                    if staffIds.isEmpty {
                        DispatchQueue.main.async {
                            self.percentMonthFilled = 0
                            self.monthlyProjectedIncome = 0
                            self.maxPossibleThisMonth = 0
                        }
                        return
                    }

                    var totalSlots = 0
                    var bookedSlots = 0
                    let group = DispatchGroup()

                    for staffId in staffIds {
                        group.enter()

                        self.db
                            .collection("businesses")
                            .document(businessId)
                            .collection("staff")
                            .document(staffId)
                            .collection("availableSlots")
                            .whereField("startTime", isGreaterThanOrEqualTo: monthRange.start)
                            .whereField("startTime", isLessThan: monthRange.end)
                            .getDocuments { snap, _ in

                                let docs = snap?.documents ?? []
                                totalSlots += docs.count
                                bookedSlots += docs.filter { ($0["isBooked"] as? Bool) == true }.count
                                group.leave()
                            }
                    }

                    group.notify(queue: .main) {
                        let remainingSlots = max(0, totalSlots - bookedSlots)

                        self.percentMonthFilled =
                            totalSlots > 0 ? (Double(bookedSlots) / Double(totalSlots)) * 100 : 0

                        // If avgPrice still 0, we can’t project money yet (no priced services + no bookings)
                        guard avgPrice > 0 else {
                            self.monthlyProjectedIncome = 0
                            self.maxPossibleThisMonth = 0
                            return
                        }

                        // Projected = remaining opportunity
                        self.monthlyProjectedIncome =
                            Int(Double(remainingSlots) * avgPrice * 100)

                        // Max Possible = full capacity
                        self.maxPossibleThisMonth =
                            Int(Double(totalSlots) * avgPrice * 100)
                    }
                }
        }
    }

    private func fetchAverageServicePrice(
        businessId: String,
        completion: @escaping (Double) -> Void
    ) {
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snapshot, _ in

                // Pull numeric prices only
                let prices: [Double] = snapshot?.documents.compactMap { doc in
                    // If your BusinessService decode is reliable, you can do:
                    // (try? doc.data(as: BusinessService.self))?.price
                    // But this is safer during migrations:
                    if let p = doc["price"] as? Double { return p }
                    if let p = doc["price"] as? Int { return Double(p) }
                    if let p = doc["price"] as? NSNumber { return p.doubleValue }
                    return nil
                } ?? []

                let avg = prices.isEmpty ? 0 : prices.reduce(0, +) / Double(prices.count)
                completion(avg)
            }
    }
}

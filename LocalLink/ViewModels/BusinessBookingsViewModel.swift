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
    @Published var monthlyRevenueEarned: Int = 0              // completed in selected month
    @Published var remainingThisMonth: Int = 0                // confirmed (future + today) in selected month
    @Published var monthlyRefunds: Int = 0
    @Published var monthlyCompletedCount: Int = 0
    @Published var percentMonthFilled: Double = 0             // % of slots booked across whole month (capacity metric)
    @Published var monthlyProjectedIncome: Int = 0            // NOW: forecast month-end revenue (business metric)
    @Published var maxPossibleThisMonth: Int = 0              // totalSlots * avgPrice (capacity value)

    // NEW: forecasting detail
    @Published var fillRateSoFarPercent: Double = 0           // elapsed booked ÷ elapsed capacity
    @Published var forecastMonthEndRevenue: Int = 0           // same value as monthlyProjectedIncome
    @Published var pipelineRevenueThisMonth: Int = 0          // confirmed (not completed) value in selected month

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                let todayMidnight = Date().localMidnight()

                self.upcoming = bookings
                    .filter {
                        $0.status == .confirmed &&
                        (($0.bookingDay ?? $0.startDate.localMidnight()) >= todayMidnight)
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

                // confirmed revenue (pipeline) in the selected month
                self.pipelineRevenueThisMonth = confirmed.reduce(0) { $0 + $1.price }

                // keep your existing property name working
                self.remainingThisMonth = self.pipelineRevenueThisMonth

                self.monthlyRefunds = refunded.reduce(0) { $0 + $1.price }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
    // CAPACITY + PROJECTION (Forecasting)
    // =================================================
    private func loadCapacityAndProjections(businessId: String) {

        let cal = Calendar.current
        guard let monthRange = cal.dateInterval(of: .month, for: selectedMonth) else { return }

        // Forecast should be based on *elapsed* performance up to today (if selected month is current month).
        // If selected month is in the past -> treat elapsed as the whole month.
        // If selected month is in the future -> elapsed is 0, forecast = pipeline (or 0 depending on preference).
        let now = Date()
        let startOfToday = now.localMidnight()
        let isSelectedMonthCurrent = cal.isDate(now, equalTo: selectedMonth, toGranularity: .month)

        // Define the "elapsed end" bound.
        // - Current month: end bound = start of tomorrow (so today counts as elapsed trading day)
        // - Past month: end bound = monthRange.end
        // - Future month: end bound = monthRange.start (elapsed = 0)
        let elapsedEnd: Date = {
            if isSelectedMonthCurrent {
                return cal.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            }
            if monthRange.end <= startOfToday {
                return monthRange.end
            }
            return monthRange.start
        }()

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
                        self.forecastMonthEndRevenue = 0
                        self.fillRateSoFarPercent = 0
                        self.maxPossibleThisMonth = 0
                        return
                    }

                    var totalSlotsInMonth = 0
                    var bookedSlotsInMonth = 0

                    var elapsedSlots = 0
                    var elapsedBookedSlots = 0

                    let group = DispatchGroup()

                    for staffId in staffIds {

                        group.enter()

                        let slotsRef = self.db.collection("businesses")
                            .document(businessId)
                            .collection("staff")
                            .document(staffId)
                            .collection("availableSlots")

                        // 1) Entire month
                        slotsRef
                            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: monthRange.start))
                            .whereField("startTime", isLessThan: Timestamp(date: monthRange.end))
                            .getDocuments { monthSnap, _ in

                                let monthDocs = monthSnap?.documents ?? []
                                totalSlotsInMonth += monthDocs.count
                                bookedSlotsInMonth += monthDocs.filter { ($0["isBooked"] as? Bool) == true }.count

                                // 2) Elapsed period (for fill-rate forecasting)
                                slotsRef
                                    .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: monthRange.start))
                                    .whereField("startTime", isLessThan: Timestamp(date: elapsedEnd))
                                    .getDocuments { elapsedSnap, _ in

                                        let elapsedDocs = elapsedSnap?.documents ?? []
                                        elapsedSlots += elapsedDocs.count
                                        elapsedBookedSlots += elapsedDocs.filter { ($0["isBooked"] as? Bool) == true }.count

                                        group.leave()
                                    }
                            }
                    }

                    group.notify(queue: .main) {

                        // Capacity % for the whole month (your existing metric)
                        self.percentMonthFilled =
                            totalSlotsInMonth > 0
                            ? (Double(bookedSlotsInMonth) / Double(totalSlotsInMonth)) * 100
                            : 0

                        guard avgPrice > 0 else {
                            self.monthlyProjectedIncome = 0
                            self.forecastMonthEndRevenue = 0
                            self.fillRateSoFarPercent = 0
                            self.maxPossibleThisMonth = 0
                            return
                        }

                        let avgPricePence = Int((avgPrice * 100).rounded())

                        // Capacity value for whole month
                        self.maxPossibleThisMonth = totalSlotsInMonth * avgPricePence

                        // Fill-rate so far
                        let fillRateSoFar: Double =
                            elapsedSlots > 0
                            ? (Double(elapsedBookedSlots) / Double(elapsedSlots))
                            : 0

                        self.fillRateSoFarPercent = fillRateSoFar * 100

                        // Forecast month-end revenue (business-style)
                        // Option A: forecast purely from fill-rate × max capacity
                        let forecast = Int((Double(self.maxPossibleThisMonth) * fillRateSoFar).rounded())

                        // Option B (safer): don’t forecast below already-locked-in pipeline+earned
                        let floorValue = self.monthlyRevenueEarned + self.pipelineRevenueThisMonth
                        self.forecastMonthEndRevenue = max(forecast, floorValue)

                        // Keep your existing field name working for UI
                        self.monthlyProjectedIncome = self.forecastMonthEndRevenue
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

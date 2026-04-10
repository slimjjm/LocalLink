import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

@MainActor
final class BusinessBookingsViewModel: ObservableObject {

    // MARK: - Published

    @Published var staff: [Staff] = []

    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []

    @Published var selectedDate: Date = Date().localMidnight()
    @Published var selectedMonth: Date = Date()

    @Published var monthlyRevenueEarned: Int = 0
    @Published var remainingThisMonth: Int = 0
    @Published var monthlyRefunds: Int = 0
    @Published var monthlyCompletedCount: Int = 0
    @Published var percentMonthFilled: Double = 0
    @Published var monthlyProjectedIncome: Int = 0
    @Published var maxPossibleThisMonth: Int = 0

    @Published var forecastMonthEndRevenue: Int = 0
    @Published var pipelineRevenueThisMonth: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private

    private let db = Firestore.firestore()
    private var currentBusinessId: String?

    private var bookingsListener: ListenerRegistration?
    private var staffListener: ListenerRegistration?

    // 🔥 Keep all bookings in memory (important improvement)
    private var allBookings: [Booking] = []

    deinit {
        bookingsListener?.remove()
        staffListener?.remove()
    }

    // =================================================
    // 🚀 START
    // =================================================

    func start(businessId: String) {
        loadBookings(for: businessId)
    }

    var error: String? {
        errorMessage
    }

    // =================================================
    // 🧠 SINGLE SOURCE OF TRUTH (DAY FILTERING)
    // =================================================

    func bookings(for date: Date) -> [Booking] {

        let cal = Calendar.current
        let target = date.localMidnight()

        return upcoming.filter {
            let day = ($0.bookingDay ?? $0.startDate).localMidnight()
            return cal.isDate(day, inSameDayAs: target)
        }
        .sorted { $0.startDate < $1.startDate }
    }

    var todayBookings: [Booking] {
        bookings(for: Date())
    }

    var tomorrowBookings: [Booking] {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return [] }
        return bookings(for: tomorrow)
    }

    var futureBookings: [Booking] {
        let cal = Calendar.current

        return upcoming.filter {
            !cal.isDateInToday($0.startDate) &&
            !cal.isDateInTomorrow($0.startDate)
        }
    }

    // =================================================
    // 🔥 BOOKINGS LISTENER
    // =================================================

    func loadBookings(for businessId: String) {

        currentBusinessId = businessId
        isLoading = true
        errorMessage = nil

        bookingsListener?.remove()

        bookingsListener = db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in

                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    print("❌ bookings error:", error)
                    return
                }

                let bookings: [Booking] = snapshot?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                // 🔥 Store everything (important)
                self.allBookings = bookings

                self.processBookings()
            }
    }

    // =================================================
    // 🧠 PROCESS BOOKINGS (CENTRALISED)
    // =================================================

    private func processBookings() {

        let todayMidnight = Date().localMidnight()

        upcoming = allBookings
            .filter {
                $0.status == .confirmed &&
                (($0.bookingDay ?? $0.startDate.localMidnight()) >= todayMidnight)
            }
            .sorted { $0.startDate < $1.startDate }

        past = allBookings
            .filter { $0.status != .confirmed }
            .sorted { $0.startDate > $1.startDate }

        calculateMonthlyStats()
    }

    // =================================================
    // 📊 MONTHLY STATS
    // =================================================

    private func calculateMonthlyStats() {

        let cal = Calendar.current

        // ✅ SAFE start of month
        guard let startOfMonth = cal.date(
            from: cal.dateComponents([.year, .month], from: selectedMonth)
        ) else {
            print("❌ ERROR: Failed to calculate startOfMonth")
            return
        }

        // ✅ SAFE end of month
        guard let endOfMonth = cal.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: startOfMonth
        ) else {
            print("❌ ERROR: Failed to calculate endOfMonth")
            return
        }

        print("📅 Month range:")
        print("➡️ Start:", startOfMonth)
        print("➡️ End:", endOfMonth)

        // 🔍 FILTER BOOKINGS
        let monthBookings = allBookings.filter {

            let date = ($0.bookingDay ?? $0.startDate)

            let inRange = date >= startOfMonth && date <= endOfMonth

            if inRange {
                print("✅ INCLUDED:", date, "| £\($0.price)")
            } else {
                print("⛔️ EXCLUDED:", date)
            }

            return inRange
        }

        print("📊 Total bookings:", allBookings.count)
        print("📊 Month bookings:", monthBookings.count)

        // 🔥 STATUS FILTERS
        let completed = monthBookings.filter { $0.status == .completed }
        let confirmed = monthBookings.filter { $0.status == .confirmed }
        let refunded = monthBookings.filter { $0.status == .refunded }

        print("✅ Completed:", completed.count)
        print("📌 Confirmed:", confirmed.count)
        print("💸 Refunded:", refunded.count)

        // 💰 CALCULATIONS
        monthlyCompletedCount = completed.count
        monthlyRevenueEarned = completed.reduce(0) { $0 + $1.price }
        pipelineRevenueThisMonth = confirmed.reduce(0) { $0 + $1.price }
        remainingThisMonth = pipelineRevenueThisMonth
        monthlyRefunds = refunded.reduce(0) { $0 + $1.price }
        monthlyProjectedIncome = pipelineRevenueThisMonth

        print("💰 Earned:", monthlyRevenueEarned)
        print("📈 Pipeline:", pipelineRevenueThisMonth)

        loadCapacityAndProjections()
    }
    // =================================================
    // 👥 STAFF
    // =================================================

    func loadStaff(for businessId: String) {

        staffListener?.remove()

        staffListener = db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .addSnapshotListener { snapshot, _ in

                guard let docs = snapshot?.documents else { return }

                self.staff = docs.compactMap {
                    try? $0.data(as: Staff.self)
                }
            }
    }

    // =================================================
    // 📅 MONTH NAVIGATION
    // =================================================

    var selectedMonthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    func goToNextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = next
            calculateMonthlyStats() // 🔥 no refetch needed
        }
    }

    func goToPreviousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = prev
            calculateMonthlyStats()
        }
    }

    // =================================================
    // 📈 CAPACITY
    // =================================================

    private func loadCapacityAndProjections() {

        guard let businessId = currentBusinessId else { return }

        let cal = Calendar.current
        guard let monthRange = cal.dateInterval(of: .month, for: selectedMonth) else { return }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { [weak self] staffSnap, _ in

                guard let self else { return }

                let staffIds = staffSnap?.documents.map { $0.documentID } ?? []

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
                        .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: monthRange.start))
                        .whereField("startTime", isLessThan: Timestamp(date: monthRange.end))
                        .getDocuments { snap, _ in

                            let docs = snap?.documents ?? []

                            totalSlots += docs.count
                            bookedSlots += docs.filter {
                                ($0["isBooked"] as? Bool) == true
                            }.count

                            group.leave()
                        }
                }

                group.notify(queue: .main) {

                    self.percentMonthFilled =
                        totalSlots > 0
                        ? (Double(bookedSlots) / Double(totalSlots)) * 100
                        : 0
                }
            }
    }
}

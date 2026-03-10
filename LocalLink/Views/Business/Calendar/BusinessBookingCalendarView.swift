import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

// =================================================
// Calendar block model for UI
// =================================================

struct CalendarBlock: Identifiable {
    let id: String
    let staffId: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

// =================================================
// MAIN VIEW
// =================================================

struct BusinessBookingCalendarView: View {

    let businessId: String
    let staff: [Staff]

    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()

    @State private var bookingsByDay: [Date: [Booking]] = [:]
    @State private var blocksByDay: [Date: [CalendarBlock]] = [:]

    @State private var availableSlots: [AvailableSlot] = []
    @State private var selectedSlot: AvailableSlot?
    @State private var selectedStaff: Staff?

    private let calendar = Calendar.current
    private let db = Firestore.firestore()

    // =================================================
    // DAYS GRID
    // =================================================

    private var days: [Date] {

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(
                of: .weekOfMonth,
                for: monthInterval.end.addingTimeInterval(-1)
            )
        else {
            return []
        }

        var date = firstWeek.start
        var out: [Date] = []

        while date < lastWeek.end {
            out.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return out
    }

    // =================================================
    // BODY
    // =================================================

    var body: some View {

        VStack(spacing: 0) {

            monthHeader
            staffPicker

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {

                ForEach(days, id: \.self) { date in

                    let dayKey = date.localMidnight()
                    let isSelected = selectedDate == dayKey
                    let hasBooking = !(bookingsByDay[dayKey]?.isEmpty ?? true)
                    let hasBlock = !(blocksByDay[dayKey]?.isEmpty ?? true)
                    let isInCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)

                    ZStack(alignment: .bottom) {

                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(isInCurrentMonth ? .primary : .secondary.opacity(0.45))
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                Circle().fill(
                                    hasBlock
                                    ? Color.red.opacity(0.25)
                                    : isSelected
                                    ? Color.orange.opacity(0.25)
                                    : Color.clear
                                )
                            )

                        VStack(spacing: 2) {

                            let bookingCount = bookingsByDay[dayKey]?.count ?? 0

                            if bookingCount > 0 {

                                HStack(spacing: 3) {

                                    ForEach(0..<min(bookingCount, 3), id: \.self) { _ in
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 6, height: 6)
                                    }

                                    if bookingCount > 3 {
                                        Text("+")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }

                            if hasBlock {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(height: 4)
                                    .padding(.horizontal, 10)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedDate = dayKey
                        fetchSlotsForDay(dayKey)
                    }
                }
            }
            .padding()

            Divider()
                .padding(.top, 4)

            if let selectedDate {
                DayDetailList(
                    businessId: businessId,
                    date: selectedDate,
                    bookings: bookingsByDay[selectedDate] ?? [],
                    blocks: blocksByDay[selectedDate] ?? [],
                    slots: availableSlots,
                    onSlotTapped: { slot in
                        selectedSlot = slot
                    }
                )
            } else {
                Text("Tap a day to view bookings")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer(minLength: 0)
        }
        .navigationTitle("Calendar")
        .onAppear {
            if selectedStaff == nil {
                selectedStaff = staff.first
            }

            fetchMonthData()

            if let selectedDate {
                fetchSlotsForDay(selectedDate)
            }
        }
        .onChange(of: currentMonth) { _ in
            fetchMonthData()
        }
        .onChange(of: selectedStaff?.id) { _ in
            fetchMonthData()

            if let selectedDate {
                fetchSlotsForDay(selectedDate)
            } else {
                availableSlots = []
            }
        }
        .sheet(item: $selectedSlot) { slot in
            BusinessQuickBookingView(
                businessId: businessId,
                staffId: slot.staffId,
                startTime: slot.startTime,
                endTime: slot.endTime
            )
        }
    }

    // =================================================
    // STAFF PICKER
    // =================================================

    private var staffPicker: some View {

        ScrollView(.horizontal, showsIndicators: false) {

            HStack(spacing: 10) {

                ForEach(staff) { member in

                    let isSelected = selectedStaff?.id == member.id

                    Button {
                        selectedStaff = member

                        if let selectedDate {
                            fetchSlotsForDay(selectedDate)
                        }
                    } label: {
                        Text(member.name.isEmpty ? "Staff" : member.name)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.orange : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // =================================================
    // HEADER
    // =================================================

    private var monthHeader: some View {

        HStack {

            Button {
                guard let previous = calendar.date(byAdding: .month, value: -1, to: currentMonth) else { return }
                currentMonth = previous
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
            }

            Spacer()

            Text(monthTitle)
                .font(.headline)

            Spacer()

            Button {
                guard let next = calendar.date(byAdding: .month, value: 1, to: currentMonth) else { return }
                currentMonth = next
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.medium))
            }
        }
        .padding()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    // =================================================
    // FETCH BOOKINGS
    // =================================================

    private func fetchMonthData() {

        guard let range = calendar.dateInterval(of: .month, for: currentMonth) else { return }

        let selectedStaffIds = selectedStaff?.id.map { [$0] }
            ?? staff.compactMap(\.id)

        guard !selectedStaffIds.isEmpty else {
            bookingsByDay = [:]
            blocksByDay = [:]
            return
        }

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .whereField("staffId", in: selectedStaffIds)
            .whereField("startDate", isGreaterThanOrEqualTo: Timestamp(date: range.start))
            .whereField("startDate", isLessThan: Timestamp(date: range.end))
            .getDocuments { snap, error in

                if let error {
                    print("❌ Failed to fetch calendar bookings:", error)
                    return
                }

                let bookings = snap?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                DispatchQueue.main.async {
                    self.bookingsByDay = Dictionary(grouping: bookings) {
                        $0.startDate.localMidnight()
                    }
                }
            }
    }

    // =================================================
    // FETCH SLOTS
    // =================================================

    private func fetchSlotsForDay(_ date: Date) {

        guard let staffId = selectedStaff?.id else {
            availableSlots = []
            return
        }

        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            availableSlots = []
            return
        }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availableSlots")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("startTime", isLessThan: Timestamp(date: end))
            .getDocuments { snap, error in

                if let error {
                    print("❌ Failed to fetch slots:", error)
                    return
                }

                let slots = snap?.documents.compactMap {
                    try? $0.data(as: AvailableSlot.self)
                } ?? []

                DispatchQueue.main.async {
                    self.availableSlots = slots.sorted { $0.startTime < $1.startTime }
                }
            }
    }

    // =================================================
    // DAY DETAIL
    // =================================================

    struct DayDetailList: View {

        let businessId: String
        let date: Date
        let bookings: [Booking]
        let blocks: [CalendarBlock]
        let slots: [AvailableSlot]

        let onSlotTapped: (AvailableSlot) -> Void

        var body: some View {

            ScrollView {

                VStack(alignment: .leading, spacing: 10) {

                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .padding(.bottom, 4)

                    timeline
                }
                .padding()
            }
        }

        // ============================================
        // TIMELINE
        // ============================================

        private var timeline: some View {

            VStack(spacing: 0) {

                ForEach(slots) { slot in

                    let booking = bookings.first {
                        Calendar.current.isDate($0.startDate, equalTo: slot.startTime, toGranularity: .minute)
                    }

                    HStack(alignment: .center, spacing: 12) {

                        Text(slot.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)

                        Divider()

                        if let booking {

                            VStack(alignment: .leading, spacing: 4) {

                                Text(booking.safeServiceName)
                                    .font(.subheadline.weight(.semibold))

                                Text(booking.safeCustomerName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(8)

                        } else {

                            Button {
                                onSlotTapped(slot)
                            } label: {
                                HStack {
                                    Text("Available")
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                            }
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(8)
                        }
                    }
                    .frame(height: 50)
                }

                if slots.isEmpty {
                    HStack {
                        Text("No available slots")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
}

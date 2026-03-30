// =================================================
// (FULL FILE — NOTHING REMOVED)
// =================================================

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

// =================================================
// MODELS
// =================================================

struct CalendarBlock: Identifiable {
    let id: String
    let staffId: String
    let title: String
    let startDate: Date
    let endDate: Date
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

    var body: some View {

        VStack(spacing: 0) {

            monthHeader
            staffPicker

            // WEEKDAY HEADER
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                    Text(day.prefix(3))
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 7),
                spacing: 12
            ) {
                ForEach(days, id: \.self) { date in
                    calendarCell(for: date)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            Divider()

            if let selectedDate {
                DayDetailList(
                    bookings: bookingsByDay[selectedDate] ?? [],
                    blocks: blocksByDay[selectedDate] ?? [],
                    slots: availableSlots,
                    onSlotTapped: { selectedSlot = $0 }
                )
            } else {
                Text("Tap a day")
                    .foregroundColor(.secondary)
                    .padding()
            }

            Spacer()
        }
        .navigationTitle("Calendar")
        .background(AppColors.background.ignoresSafeArea())

        .onAppear {
            selectedStaff = staff.first
            fetchMonthData()
        }

        .onChange(of: currentMonth) { _ in
            selectedDate = nil
            availableSlots = []
            fetchMonthData()
        }

        .onChange(of: selectedStaff?.id) { _ in
            fetchMonthData()
            if let selectedDate {
                fetchSlotsForDay(selectedDate)
            }
        }

        .sheet(item: $selectedSlot) { slot in
            BusinessQuickBookingView(
                businessId: businessId,
                staffId: slot.staffId,
                startTime: slot.startTime
            )
        }
    }

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
        else { return [] }

        var date = firstWeek.start
        var out: [Date] = []

        while date < lastWeek.end {
            out.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return out
    }

    // =================================================
    // HEADER
    // =================================================

    private var monthHeader: some View {
        HStack {
            Button {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(AppColors.charcoal)
            }

            Spacer()

            Text(currentMonth.formatted(.dateTime.month().year()))
                .font(.title2.bold())
                .foregroundColor(AppColors.charcoal)

            Spacer()

            Button {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(AppColors.charcoal)
            }
        }
        .padding()
        .background(Color.white)
    }

    // =================================================
    // STAFF PICKER
    // =================================================

    private var staffPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(staff) { s in
                    Button {
                        selectedStaff = s
                    } label: {
                        Text(s.name)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedStaff?.id == s.id
                                ? AppColors.primary   // ✅ FIXED
                                : Color.white
                            )
                            .foregroundColor(
                                selectedStaff?.id == s.id
                                ? .white
                                : AppColors.charcoal
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2))
                            )
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // =================================================
    // CELL
    // =================================================

    private func calendarCell(for date: Date) -> some View {

        let day = calendar.startOfDay(for: date)
        let isSelected = selectedDate == day
        let isToday = calendar.isDateInToday(day)

        let hasBookings = bookingsByDay[day]?.isEmpty == false
        let hasBlocks = blocksByDay[day]?.isEmpty == false

        return VStack(spacing: 6) {

            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline.bold())
                .foregroundColor(
                    isSelected ? .white : AppColors.charcoal
                )

            HStack(spacing: 4) {
                if hasBookings {
                    Circle().fill(AppColors.success).frame(width: 6, height: 6)
                }
                if hasBlocks {
                    Circle().fill(AppColors.error).frame(width: 6, height: 6)
                }
            }
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(isSelected ? AppColors.primary : Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday ? AppColors.primary : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .onTapGesture {
            selectedDate = day
            fetchSlotsForDay(day)
        }
    }

    // =================================================
    // FETCH DATA (SAFE QUERY INCLUDED)
    // =================================================

    private func fetchMonthData() {
        fetchBookings()
        fetchBlocks()
    }

    private func fetchBookings() {

        guard let range = calendar.dateInterval(of: .month, for: currentMonth) else { return }

        let staffIds = selectedStaff?.id.map { [$0] } ?? staff.compactMap(\.id)

        var query = db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("status", isEqualTo: BookingStatus.confirmed.rawValue)
            .whereField("startDate", isGreaterThanOrEqualTo: Timestamp(date: range.start))
            .whereField("startDate", isLessThan: Timestamp(date: range.end))

        if staffIds.count == 1 {
            query = query.whereField("staffId", isEqualTo: staffIds[0])
        } else if !staffIds.isEmpty {
            query = query.whereField("staffId", in: Array(staffIds.prefix(10)))
        }

        query.getDocuments { snap, error in
            if let error {
                print("❌ bookings error:", error)
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

    private func fetchBlocks() {

        guard let staffId = selectedStaff?.id else { return }

        db.collection("businesses")
            .document(businessId)
            .collection("timeBlocks")
            .whereField("staffId", isEqualTo: staffId)
            .getDocuments { snapshot, _ in

                var map: [Date: [CalendarBlock]] = [:]

                snapshot?.documents.forEach { doc in
                    guard
                        let start = (doc["startDate"] as? Timestamp)?.dateValue(),
                        let end = (doc["endDate"] as? Timestamp)?.dateValue(),
                        let title = doc["title"] as? String
                    else { return }

                    let day = calendar.startOfDay(for: start)

                    let block = CalendarBlock(
                        id: doc.documentID,
                        staffId: staffId,
                        title: title,
                        startDate: start,
                        endDate: end
                    )

                    map[day, default: []].append(block)
                }

                DispatchQueue.main.async {
                    self.blocksByDay = map
                }
            }
    }

    private func fetchSlotsForDay(_ date: Date) {

        guard let staffId = selectedStaff?.id else {
            availableSlots = []
            return
        }

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .collection("availableSlots")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("startTime", isLessThan: Timestamp(date: end))
            .getDocuments { snap, error in

                if let error {
                    print("❌ slots error:", error)
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
}

// =================================================
// DAY DETAIL LIST (FULL INCLUDED)
// =================================================

struct DayDetailList: View {

    let bookings: [Booking]
    let blocks: [CalendarBlock]
    let slots: [AvailableSlot]
    let onSlotTapped: (AvailableSlot) -> Void

    var body: some View {

        ScrollView {
            VStack(spacing: 20) {

                if !blocks.isEmpty {
                    sectionHeader("Blocked Time")

                    ForEach(blocks) { block in
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .foregroundColor(AppColors.error)

                            VStack(alignment: .leading) {
                                Text(block.title).font(.subheadline.bold())
                                Text("\(block.startDate.formatted(date: .omitted, time: .shortened)) - \(block.endDate.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(AppColors.error.opacity(0.12))
                        .cornerRadius(12)
                    }
                }

                if !bookings.isEmpty {
                    sectionHeader("Bookings")

                    ForEach(bookings) { booking in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)

                            Text(booking.safeServiceName)
                                .font(.subheadline.bold())

                            Spacer()
                        }
                        .padding()
                        .background(AppColors.success.opacity(0.12))
                        .cornerRadius(12)
                    }
                }

                if !slots.isEmpty {
                    sectionHeader("Available Slots")

                    ForEach(slots) { slot in
                        Button {
                            onSlotTapped(slot)
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                Text(slot.startTime.formatted(date: .omitted, time: .shortened))
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(AppColors.primary)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

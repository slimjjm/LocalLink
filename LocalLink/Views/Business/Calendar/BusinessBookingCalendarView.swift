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
    let staffIds: [String]

    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()

    @State private var bookingsByDay: [Date: [Booking]] = [:]
    @State private var blocksByDay: [Date: [CalendarBlock]] = [:]

    // NEW
    @State private var availableSlots: [AvailableSlot] = []
    @State private var selectedSlot: AvailableSlot?

    private let calendar = Calendar.current
    private let db = Firestore.firestore()

    // =================================================
    // DAYS GRID
    // =================================================

    private var days: [Date] {

        guard
            let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
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
    // BODY
    // =================================================

    var body: some View {

        VStack {

            monthHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {

                ForEach(days, id: \.self) { date in

                    let dayKey = date.localMidnight()

                    let hasBooking = (bookingsByDay[dayKey]?.isEmpty == false)
                    let hasBlock = (blocksByDay[dayKey]?.isEmpty == false)

                    ZStack(alignment: .bottom) {

                        Text("\(calendar.component(.day, from: date))")
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                Circle().fill(
                                    hasBlock
                                    ? Color.red.opacity(0.25)
                                    : selectedDate == dayKey
                                        ? Color.orange.opacity(0.3)
                                        : Color.clear
                                )
                            )

                        VStack(spacing: 2) {

                            if hasBooking {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.orange)
                                    .frame(height: 4)
                                    .padding(.horizontal, 6)
                            }

                            if hasBlock {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red)
                                    .frame(height: 4)
                                    .padding(.horizontal, 6)
                            }
                        }
                        .padding(.bottom, 4)
                        .padding(.bottom, 4)
                    }
                    .onTapGesture {
                        selectedDate = dayKey
                        fetchSlotsForDay(dayKey)
                    }
                }
            }
            .padding()

            Divider()

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
            }

            Spacer()
        }
        .navigationTitle("Calendar")
        .onAppear {

            selectedDate = Date().localMidnight()

            fetchMonthData()

            if let selectedDate {
                fetchSlotsForDay(selectedDate)
            }
        }
        .onChange(of: currentMonth) { _ in
            fetchMonthData()
        }

        // SLOT BOOKING SHEET
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
    // HEADER
    // =================================================

    private var monthHeader: some View {

        HStack {

            Button {
                currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
            } label: { Image(systemName: "chevron.left") }

            Spacer()

            Text(monthTitle).font(.headline)

            Spacer()

            Button {
                currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
            } label: { Image(systemName: "chevron.right") }
        }
        .padding()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    // =================================================
    // FETCH BOOKINGS + BLOCKS
    // =================================================

    private func fetchMonthData() {

        guard let range = calendar.dateInterval(of: .month, for: currentMonth) else { return }

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("status", isEqualTo: "confirmed")
            .whereField("staffId", in: staffIds)
            .whereField("startDate", isGreaterThanOrEqualTo: Timestamp(date: range.start))
            .whereField("startDate", isLessThan: Timestamp(date: range.end))
            .getDocuments { snap, error in

                if let error {
                    print("❌ Failed to fetch calendar bookings:", error)
                    return
                }

                let bookings = snap?.documents.compactMap { try? $0.data(as: Booking.self) } ?? []

                DispatchQueue.main.async {
                    self.bookingsByDay = Dictionary(grouping: bookings) {
                        $0.startDate.localMidnight()
                    }
                }
            }
    }

    // =================================================
    // FETCH SLOTS FOR DAY
    // =================================================

    private func fetchSlotsForDay(_ date: Date) {

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        var slots: [AvailableSlot] = []

        let group = DispatchGroup()

        for staffId in staffIds {

            group.enter()

            db.collection("businesses")
                .document(businessId)
                .collection("staff")
                .document(staffId)
                .collection("availableSlots")
                .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("startTime", isLessThan: Timestamp(date: end))
                .whereField("isBooked", isEqualTo: false)
                .getDocuments { snap, _ in

                    if let docs = snap?.documents {

                        let fetched = docs.compactMap {
                            try? $0.data(as: AvailableSlot.self)
                        }

                        slots.append(contentsOf: fetched)
                    }

                    group.leave()
                }
        }

        group.notify(queue: .main) {

            self.availableSlots = slots.sorted {
                $0.startTime < $1.startTime
            }
        }
    }

    // =================================================
    // DAY DETAIL LIST
    // =================================================

    struct DayDetailList: View {

        let businessId: String
        let date: Date
        let bookings: [Booking]
        let blocks: [CalendarBlock]
        let slots: [AvailableSlot]

        let onSlotTapped: (AvailableSlot) -> Void

        var body: some View {

            VStack(alignment: .leading, spacing: 8) {

                if !bookings.isEmpty {

                    Text("Bookings").font(.headline)

                    ForEach(bookings) { booking in

                        NavigationLink {
                            BookingDetailView(
                                bookingId: booking.id ?? "",
                                currentUserRole: "business"
                            )
                        } label: {
                            Text(
                                "\(booking.startDate.formatted(date: .omitted, time: .shortened)) – \(booking.serviceName)"
                            )
                        }
                    }
                }

                if !slots.isEmpty {

                    Text("Available").font(.headline).padding(.top)

                    ForEach(slots) { slot in

                        Button {

                            onSlotTapped(slot)

                        } label: {

                            HStack {

                                Text(
                                    slot.startTime.formatted(
                                        date: .omitted,
                                        time: .shortened
                                    )
                                )

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                if bookings.isEmpty && slots.isEmpty {

                    Text("No bookings or available slots.")
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
    }
}

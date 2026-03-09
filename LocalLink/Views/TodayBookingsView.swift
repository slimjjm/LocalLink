import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct TodayBookingsView: View {

    let businessId: String

    @State private var items: [TodayScheduleItem] = []
    @State private var isLoading = true

    private let db = Firestore.firestore()

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("Today’s Jobs")
                .font(.title2.bold())

            if isLoading {
                ProgressView()
            } else if items.isEmpty {
                Text("No jobs scheduled today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(items) { item in
                    switch item {

                    case .booking(let booking):
                        NavigationLink {
                            BookingDetailView(
                                bookingId: booking.id ?? "",
                                currentUserRole: "business"
                            )
                        } label: {
                            jobCard(booking)
                        }

                    case .timeBlock(let block):
                        timeBlockCard(block)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteTimeBlock(block)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                    case .dayBlock(let block):
                        dayBlockCard(block)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteDayBlock(block)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { loadTodayData() }
    }

    // MARK: - Booking Card

    private func jobCard(_ booking: Booking) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(booking.safeServiceName)
                .font(.headline)

            Text(booking.startDate.formatted(date: .omitted, time: .shortened))
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(booking.safeCustomerName)
                .font(.subheadline)

            if !booking.safeCustomerAddress.isEmpty {
                Text(booking.safeCustomerAddress)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Time Block Card

    private func timeBlockCard(_ block: TimeBlockItem) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Image(systemName: "calendar.badge.minus")
                    .foregroundColor(.red)

                Text(block.title)
                    .font(.headline)
            }

            Text(
                "\(block.startDate.formatted(date: .omitted, time: .shortened)) – " +
                "\(block.endDate.formatted(date: .omitted, time: .shortened))"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            Text("Staff: \(block.staffId.prefix(6))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.10))
        )
    }

    // MARK: - Day Block Card

    private func dayBlockCard(_ block: DayBlockItem) -> some View {

        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundColor(.red)

                Text(block.reason)
                    .font(.headline)
            }

            Text("All day")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Staff: \(block.staffId.prefix(6))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.10))
        )
    }

    // MARK: - Delete

    private func deleteTimeBlock(_ block: TimeBlockItem) {
        db.collection("businesses")
            .document(businessId)
            .collection("timeBlocks")
            .document(block.id)
            .delete { _ in
                loadTodayData()
            }
    }

    private func deleteDayBlock(_ block: DayBlockItem) {
        db.collection("businesses")
            .document(businessId)
            .collection("dayBlocks")
            .document(block.id)
            .delete { _ in
                loadTodayData()
            }
    }

    // MARK: - Load Today Data

    private func loadTodayData() {

        isLoading = true

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let group = DispatchGroup()

        var bookings: [Booking] = []
        var timeBlocks: [TimeBlockItem] = []
        var dayBlocks: [DayBlockItem] = []

        // BOOKINGS
        group.enter()
        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("startDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("startDate", isLessThan: Timestamp(date: endOfDay))
            .getDocuments { snap, _ in
                bookings = snap?.documents.compactMap { try? $0.data(as: Booking.self) } ?? []
                group.leave()
            }

        // TIME BLOCKS (overlapping today)
        group.enter()
        db.collection("businesses")
            .document(businessId)
            .collection("timeBlocks")
            .whereField("startDate", isLessThan: Timestamp(date: endOfDay))
            .whereField("endDate", isGreaterThan: Timestamp(date: startOfDay))
            .getDocuments { snap, _ in

                let docs = snap?.documents ?? []

                timeBlocks = docs.compactMap { doc in
                    guard let tb = try? doc.data(as: TimeBlock.self) else { return nil }
                    return TimeBlockItem(
                        id: doc.documentID,
                        staffId: tb.staffId,
                        title: tb.title,
                        startDate: tb.startDate,
                        endDate: tb.endDate
                    )
                }

                group.leave()
            }

        // DAY BLOCKS (covers today)
        group.enter()
        db.collection("businesses")
            .document(businessId)
            .collection("dayBlocks")
            .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("endDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .getDocuments { snap, _ in

                let docs = snap?.documents ?? []

                dayBlocks = docs.compactMap { doc in
                    guard let dbk = try? doc.data(as: DayBlock.self) else { return nil }
                    return DayBlockItem(
                        id: doc.documentID,
                        staffId: dbk.staffId,
                        reason: dbk.reason,
                        startDate: dbk.startDate,
                        endDate: dbk.endDate
                    )
                }

                group.leave()
            }

        group.notify(queue: .main) {

            let merged: [TodayScheduleItem] =
                bookings.map { .booking($0) } +
                timeBlocks.map { .timeBlock($0) } +
                dayBlocks.map { .dayBlock($0) }

            self.items = merged.sorted { $0.startDate < $1.startDate }
            self.isLoading = false
        }
    }
}

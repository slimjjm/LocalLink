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
            }
            else if items.isEmpty {
                Text("No jobs scheduled today")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            else {
                ForEach(items) { item in
                    switch item {

                    case .booking(let booking):
                        NavigationLink {
                            BookingDetailView(bookingId: booking.id ?? "")
                        } label: {
                            jobCard(booking)
                        }

                    case .blocked(let block):
                        blockedCard(block)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deleteBlock(block)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadTodayData()
        }
    }

    // MARK: - Booking Card

    private func jobCard(_ booking: Booking) -> some View {
        ZStack(alignment: .topTrailing) {

            VStack(alignment: .leading, spacing: 6) {

                Text(booking.serviceName)
                    .font(.headline)

                Text(booking.startDate.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(booking.customerName)
                    .font(.subheadline)

                if !booking.customerAddress.isEmpty {
                    Text(booking.customerAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )

            // ⭐ Paid badge
            if booking.isPaid == true {
                Text("PAID")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .clipShape(Capsule())
                    .padding(8)
            }
        }
    }


    // MARK: - Block Card

    private func blockedCard(_ block: BlockedTime) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            HStack {
                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)

                Text(block.title)
                    .font(.headline)
            }

            Text(
                "\(block.startDate.formatted(date: .omitted, time: .shortened)) – " +
                "\(block.endDate.formatted(date: .omitted, time: .shortened))"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.12))
        )
    }

    // MARK: - Delete Block

    private func deleteBlock(_ block: BlockedTime) {
        guard let id = block.id else { return }

        db.collection("blockedTimes")
            .document(id)
            .delete { _ in
                loadTodayData()
            }
    }

    // MARK: - Load Data

    private func loadTodayData() {

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Load bookings
        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("startDate", isGreaterThanOrEqualTo: startOfDay)
            .whereField("startDate", isLessThan: endOfDay)
            .getDocuments { bookingSnap, _ in

                let bookings = bookingSnap?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []

                // Load blocked times
                db.collection("blockedTimes")
                    .whereField("businessId", isEqualTo: businessId)
                    .whereField("startDate", isGreaterThanOrEqualTo: startOfDay)
                    .whereField("startDate", isLessThan: endOfDay)
                    .getDocuments { blockSnap, _ in

                        let blocks = blockSnap?.documents.compactMap {
                            try? $0.data(as: BlockedTime.self)
                        } ?? []

                        DispatchQueue.main.async {
                            self.isLoading = false

                            let merged: [TodayScheduleItem] =
                                bookings.map { .booking($0) } +
                                blocks.map { .blocked($0) }

                            self.items = merged.sorted {
                                $0.startDate < $1.startDate
                            }
                        }
                    }
            }
    }
}


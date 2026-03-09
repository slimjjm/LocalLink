import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct DayBookingsListView: View {

    let businessId: String
    let date: Date

    @State private var bookings: [Booking] = []

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    var body: some View {

        VStack(alignment: .leading) {

            if bookings.isEmpty {
                Text("No jobs")
                    .foregroundColor(.secondary)
            }

            ForEach(bookings) { booking in

                VStack(alignment: .leading, spacing: 6) {

                    Text(booking.safeServiceName)
                        .font(.headline)

                    Text(booking.safeCustomerName)

                    if !booking.safeCustomerAddress.isEmpty {
                        Text(booking.safeCustomerAddress)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .onAppear { load() }
        .onChange(of: date) { _ in load() }
    }

    private func load() {

        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!

        db.collection("bookings")
            .whereField("businessId", isEqualTo: businessId)
            .whereField("startDate", isGreaterThanOrEqualTo: start)
            .whereField("startDate", isLessThan: end)
            .whereField("status", isEqualTo: "confirmed")
            .getDocuments { snap, _ in

                bookings = snap?.documents.compactMap {
                    try? $0.data(as: Booking.self)
                } ?? []
            }
    }
}

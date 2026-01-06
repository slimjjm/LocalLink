import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingDetailView: View {

    // MARK: - Inputs
    let bookingId: String

    // MARK: - State
    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var errorMessage: String?

    // MARK: - Services
    private let db = Firestore.firestore()

    // MARK: - View
    var body: some View {
        VStack(spacing: 20) {

            if isLoading {
                ProgressView("Loading booking…")
            }

            else if let booking {
                details(for: booking)
            }

            else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadBooking()
        }
    }

    // MARK: - UI

    private func details(for booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 16) {

            Text(booking.serviceName)
                .font(.largeTitle.bold())

            infoRow("Staff", booking.staffName)

            if !booking.location.isEmpty {
                infoRow("Location", booking.location)
            }

            infoRow(
                "Date",
                booking.startDate.formatted(
                    date: .long,
                    time: .omitted
                )
            )

            infoRow(
                "Time",
                booking.startDate.formatted(
                    date: .omitted,
                    time: .shortened
                )
            )

            infoRow(
                "Status",
                booking.status.rawValue.capitalized
            )
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Data

    private func loadBooking() {
        isLoading = true
        errorMessage = nil

        db.collection("bookings")
            .document(bookingId)
            .getDocument { snapshot, error in
                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    self.booking = try? snapshot?.data(as: Booking.self)
                }
            }
    }
}

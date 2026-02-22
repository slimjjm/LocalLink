import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift
import UIKit

struct BookingDetailView: View {

    let bookingId: String

    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

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

            else {
                Text("Booking not found")
                    .foregroundColor(.secondary)
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

    private func details(for booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 18) {

            Text(booking.serviceName)
                .font(.largeTitle.bold())

            Divider()

            infoRow("Staff", booking.staffName)

            if !booking.customerAddress.isEmpty {
                Button {
                    openInMaps(booking.customerAddress)
                } label: {
                    infoRow("Address", booking.customerAddress)
                }
            }

            infoRow(
                "Date",
                booking.startDate.formatted(date: .long, time: .omitted)
            )

            infoRow(
                "Time",
                booking.startDate.formatted(date: .omitted, time: .shortened)
            )

            infoRow("Duration", "\(booking.serviceDurationMinutes) mins")
            infoRow("Price", String(format: "£%.2f", booking.price))
            infoRow("Status", booking.status.rawValue.capitalized)

            infoRow(
                "Booked",
                booking.createdAt?
                    .formatted(date: .abbreviated, time: .shortened)
                    ?? "Unknown"
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

    private func openInMaps(_ address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let googleURL = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving")
        let wazeURL = URL(string: "waze://?q=\(encoded)&navigate=yes")
        let appleURL = URL(string: "http://maps.apple.com/?daddr=\(encoded)")

        if let googleURL, UIApplication.shared.canOpenURL(googleURL) {
            UIApplication.shared.open(googleURL)
            return
        }

        if let wazeURL, UIApplication.shared.canOpenURL(wazeURL) {
            UIApplication.shared.open(wazeURL)
            return
        }

        if let appleURL {
            UIApplication.shared.open(appleURL)
        }
    }

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

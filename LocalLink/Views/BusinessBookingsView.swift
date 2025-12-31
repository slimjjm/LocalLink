import SwiftUI

struct BusinessBookingsView: View {

    let businessId: String
    @StateObject private var viewModel = BusinessBookingsViewModel()

    var body: some View {
        List {

            // Loading state
            if viewModel.isLoading {
                ProgressView("Loading bookings…")
            }

            // Error state
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            // Empty state
            if !viewModel.isLoading && viewModel.upcoming.isEmpty {
                Text("No upcoming bookings")
                    .foregroundColor(.secondary)
            }

            // Bookings
            ForEach(viewModel.upcoming) { booking in
                BusinessBookingRowView(
                    booking: booking,
                    onCancelled: {
                        viewModel.loadBookings(for: businessId)
                    }
                )
            }
        }
        .navigationTitle("Bookings")
        .onAppear {
            viewModel.loadBookings(for: businessId)
        }
    }
}

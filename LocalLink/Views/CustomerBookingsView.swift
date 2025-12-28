import SwiftUI

struct CustomerBookingsView: View {

    @StateObject private var viewModel = CustomerBookingsViewModel()

    var body: some View {
        NavigationStack {
            List {

                if viewModel.isLoading {
                    ProgressView("Loading bookings…")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                }

                if !viewModel.upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(viewModel.upcoming) { booking in
                            BookingRowView(booking: booking)
                        }
                    }
                }

                if !viewModel.past.isEmpty {
                    Section("Past") {
                        ForEach(viewModel.past) { booking in
                            BookingRowView(booking: booking)
                        }
                    }
                }
            }
            .navigationTitle("My Bookings")
            .onAppear {
                viewModel.loadBookings()
            }
        }
    }
}

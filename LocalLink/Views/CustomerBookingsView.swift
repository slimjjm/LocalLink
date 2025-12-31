import SwiftUI

struct CustomerBookingsView: View {

    @StateObject private var viewModel = CustomerBookingsViewModel()

    var body: some View {
        NavigationStack {
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

                // Upcoming bookings
                if !viewModel.upcoming.isEmpty {
                    Section("Upcoming") {
                        ForEach(viewModel.upcoming) { booking in
                            NavigationLink {
                                BookingDetailView(booking: booking)
                            } label: {
                                BookingRowView(booking: booking)
                            }
                        }
                    }
                }

                // Past bookings
                if !viewModel.past.isEmpty {
                    Section("Past") {
                        ForEach(viewModel.past) { booking in
                            NavigationLink {
                                BookingDetailView(booking: booking)
                            } label: {
                                BookingRowView(booking: booking)
                            }
                        }
                    }
                }

                // Empty state (optional but helpful)
                if !viewModel.isLoading &&
                    viewModel.upcoming.isEmpty &&
                    viewModel.past.isEmpty {

                    Text("No bookings yet")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("My Bookings")
            .onAppear {
                viewModel.loadBookings()
            }
        }
    }
}


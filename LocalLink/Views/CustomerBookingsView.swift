import SwiftUI

struct CustomerBookingsView: View {

    @StateObject private var viewModel = CustomerBookingsViewModel()
    @EnvironmentObject private var nav: NavigationState

    var body: some View {
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
                        Button {
                            if let id = booking.id {
                                nav.path.append(
                                    AppRoute.bookingDetail(bookingId: id)
                                )
                            }
                        } label: {
                            BookingRowView(booking: booking)
                        }
                    }
                }
            }

            if !viewModel.past.isEmpty {
                Section("Past") {
                    ForEach(viewModel.past) { booking in
                        Button {
                            if let id = booking.id {
                                nav.path.append(
                                    AppRoute.bookingDetail(bookingId: id)
                                )
                            }
                        } label: {
                            BookingRowView(booking: booking)
                        }
                    }
                }
            }

            if !viewModel.isLoading &&
                viewModel.upcoming.isEmpty &&
                viewModel.past.isEmpty {

                Text("No bookings yet")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadBookings()
        }
    }
}


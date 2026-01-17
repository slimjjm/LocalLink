import SwiftUI

struct CustomerBookingsView: View {

    @StateObject private var viewModel = CustomerBookingsViewModel()
    @EnvironmentObject private var nav: NavigationState

    var body: some View {
        List {

            // Loading
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading bookings…")
                    Spacer()
                }
            }

            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            // Upcoming bookings
            if !viewModel.upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(viewModel.upcoming) { booking in
                        bookingRow(booking)
                    }
                }
            }

            // Past bookings
            if !viewModel.past.isEmpty {
                Section("Past") {
                    ForEach(viewModel.past) { booking in
                        bookingRow(booking)
                    }
                }
            }

            // Empty state
            if !viewModel.isLoading &&
               viewModel.upcoming.isEmpty &&
               viewModel.past.isEmpty {

                Text("No bookings yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadBookings()
        }
    }

    // MARK: - Booking Row Navigation

    @ViewBuilder
    private func bookingRow(_ booking: Booking) -> some View {
        Button {
            guard let id = booking.id else { return }
            nav.path.append(AppRoute.bookingDetail(bookingId: id))

        } label: {
            BookingRowView(booking: booking)
        }
    }
}

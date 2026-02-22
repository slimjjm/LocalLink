import SwiftUI

struct BusinessBookingsView: View {
    
    let businessId: String
    @StateObject private var viewModel = BusinessBookingsViewModel()

    // 🔐 Freeze today's reference ONCE per view lifecycle
    @State private var referenceToday = Date().localMidnight()

    private var today: Date {
        referenceToday
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: referenceToday)!
    }

    private var todayBookings: [Booking] {
        viewModel.upcoming
            .filter {
                ($0.bookingDay ?? $0.startDate.localMidnight()) == today
            }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private var tomorrowBookings: [Booking] {
        viewModel.upcoming
            .filter {
                ($0.bookingDay ?? $0.startDate.localMidnight()) == tomorrow
            }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private var futureBookings: [Booking] {
        viewModel.upcoming
            .filter {
                let day = $0.bookingDay ?? $0.startDate.localMidnight()
                return day != today && day != tomorrow
            }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        List {

            if viewModel.isLoading {
                ProgressView("Loading bookings…")
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            if !todayBookings.isEmpty {
                Section("Today") {
                    ForEach(todayBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                    }
                }
            }

            if !tomorrowBookings.isEmpty {
                Section("Tomorrow") {
                    ForEach(tomorrowBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                    }
                }
            }

            if !futureBookings.isEmpty {
                Section("Upcoming") {
                    ForEach(futureBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                    }
                }
            }

            if !viewModel.past.isEmpty {
                Section("Past") {
                    ForEach(viewModel.past) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bookings")
        .onAppear {
            viewModel.loadBookings(for: businessId)
        }
    }
}

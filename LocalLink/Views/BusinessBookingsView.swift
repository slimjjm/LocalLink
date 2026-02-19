import SwiftUI

struct BusinessBookingsView: View {
    
    let businessId: String
    @StateObject private var viewModel = BusinessBookingsViewModel()
    
    // MARK: - Grouped + Sorted Bookings
    
    private var todayBookings: [Booking] {
        viewModel.upcoming
            .filter { Calendar.current.isDateInToday($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private var tomorrowBookings: [Booking] {
        viewModel.upcoming
            .filter { Calendar.current.isDateInTomorrow($0.startDate) }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private var futureBookings: [Booking] {
        viewModel.upcoming
            .filter {
                !Calendar.current.isDateInToday($0.startDate) &&
                !Calendar.current.isDateInTomorrow($0.startDate)
            }
            .sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        List {
            
            // Loading
            if viewModel.isLoading {
                ProgressView("Loading bookings…")
            }
            
            // Error
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            
            // Empty
            if !viewModel.isLoading && viewModel.upcoming.isEmpty && viewModel.past.isEmpty {
                Text("No bookings yet")
                    .foregroundColor(.secondary)
            }
            
            // TODAY
            if !todayBookings.isEmpty {
                Section("Today") {
                    ForEach(todayBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            // TOMORROW
            if !tomorrowBookings.isEmpty {
                Section("Tomorrow") {
                    ForEach(tomorrowBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            // UPCOMING
            if !futureBookings.isEmpty {
                Section("Upcoming") {
                    ForEach(futureBookings) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
            
            // PAST
            if !viewModel.past.isEmpty {
                Section("Past") {
                    ForEach(viewModel.past) { booking in
                        BusinessBookingRowView(
                            booking: booking,
                            onCancelled: {
                                viewModel.loadBookings(for: businessId)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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


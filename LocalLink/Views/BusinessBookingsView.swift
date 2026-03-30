import SwiftUI

struct BusinessBookingsView: View {
    
    let businessId: String
    
    @StateObject private var viewModel = BusinessBookingsViewModel()
    @State private var referenceToday = Date().localMidnight()
    
    // MARK: - Date Helpers
    
    private var today: Date {
        referenceToday
    }
    
    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: referenceToday) ?? referenceToday
    }
    
    // MARK: - Booking Groups
    
    private var todayBookings: [Booking] {
        viewModel.upcoming
            .filter { ($0.bookingDay ?? $0.startDate.localMidnight()) == today }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private var tomorrowBookings: [Booking] {
        viewModel.upcoming
            .filter { ($0.bookingDay ?? $0.startDate.localMidnight()) == tomorrow }
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
    
    // MARK: - View
    
    var body: some View {
        
        List {
            
            if viewModel.isLoading {
                loadingSection
            }
            
            if let error = viewModel.errorMessage {
                errorSection(error)
            }
            
            if !todayBookings.isEmpty {
                bookingSection(title: "Today", bookings: todayBookings)
            }
            
            if !tomorrowBookings.isEmpty {
                bookingSection(title: "Tomorrow", bookings: tomorrowBookings)
            }
            
            if !futureBookings.isEmpty {
                bookingSection(title: "Future bookings", bookings: futureBookings)
            }
            
            if !viewModel.past.isEmpty {
                pastBookingsSection
            }
            
            if shouldShowEmptyState {
                emptyStateSection
            }
        }
        .navigationTitle("Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            referenceToday = Date().localMidnight()
            viewModel.loadBookings(for: businessId)
        }
    }
    
    // MARK: - Sections
    
    private var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView("Loading bookings…")
            Spacer()
        }
    }
    
    private func errorSection(_ error: String) -> some View {
        Text(error)
            .foregroundColor(AppColors.error)
    }
    
    private func bookingSection(title: String, bookings: [Booking]) -> some View {
        Section(title) {
            ForEach(bookings) { booking in
                NavigationLink {
                    BookingChatView(
                        bookingId: booking.id ?? "",
                        businessId: booking.businessId,
                        customerId: booking.customerId,
                        currentUserRole: "business"
                    )
                } label: {
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
    
    private var pastBookingsSection: some View {
        Section("Past bookings") {
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
    
    private var emptyStateSection: some View {
        ContentUnavailableView(
            "No bookings yet",
            systemImage: "calendar",
            description: Text("New bookings will appear here.")
        )
    }
    
    private var shouldShowEmptyState: Bool {
        !viewModel.isLoading &&
        todayBookings.isEmpty &&
        tomorrowBookings.isEmpty &&
        futureBookings.isEmpty &&
        viewModel.past.isEmpty
    }
}

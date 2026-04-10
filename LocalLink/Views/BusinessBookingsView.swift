import SwiftUI

struct BusinessBookingsView: View {
    
    let businessId: String
    
    @StateObject private var viewModel = BusinessBookingsViewModel()
    
    var body: some View {
        
        List {
            
            if viewModel.isLoading {
                loadingSection
            }
            
            if let error = viewModel.error {
                errorSection(error)
            }
            
            if shouldShowEmptyState {
                emptyStateSection
            }
            
            if !viewModel.todayBookings.isEmpty {
                bookingSection(title: "Today", bookings: viewModel.todayBookings)
            }

            if !viewModel.tomorrowBookings.isEmpty {
                bookingSection(title: "Tomorrow", bookings: viewModel.tomorrowBookings)
            }

            if !viewModel.futureBookings.isEmpty {
                bookingSection(title: "Upcoming", bookings: viewModel.futureBookings)
            }
            
            if !viewModel.past.isEmpty {
                bookingSection(title: "Past", bookings: viewModel.past)
            }
        }
        .navigationTitle("Bookings")
        .onAppear {
            viewModel.start(businessId: businessId)
        }
    }
}

// MARK: - SECTIONS

private extension BusinessBookingsView {
    
    var loadingSection: some View {
        HStack {
            Spacer()
            ProgressView("Loading bookings...")
            Spacer()
        }
    }
    
    func errorSection(_ error: String) -> some View {
        Text(error)
            .foregroundColor(AppColors.error)
    }
    
    var emptyStateSection: some View {
        VStack(spacing: 12) {
            Spacer()
            
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No bookings yet")
                .font(.headline)
            
            Text("New bookings will appear here.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - BOOKINGS

private extension BusinessBookingsView {
    
    func bookingSection(title: String, bookings: [Booking]) -> some View {
        
        Section(title) {
            ForEach(bookings) { booking in
                
                NavigationLink {
                    EnquiryChatView(
                        businessId: businessId,
                        customerId: booking.customerId
                    )
                } label: {
                    BusinessBookingRowView(
                        booking: booking,
                        onCancelled: {
                            viewModel.start(businessId: businessId)
                        }
                    )
                }
            }
        }
    }
}
// MARK: - GROUPING

private extension BusinessBookingsView {
    
    var todayBookings: [Booking] {
        viewModel.upcoming.filter { Calendar.current.isDateInToday($0.startDate) }
    }
    
    var tomorrowBookings: [Booking] {
        viewModel.upcoming.filter { Calendar.current.isDateInTomorrow($0.startDate) }
    }
    
    var futureBookings: [Booking] {
        viewModel.upcoming.filter {
            !Calendar.current.isDateInToday($0.startDate) &&
            !Calendar.current.isDateInTomorrow($0.startDate)
        }
    }
    
    var shouldShowEmptyState: Bool {
          !viewModel.isLoading &&
          viewModel.todayBookings.isEmpty &&
          viewModel.tomorrowBookings.isEmpty &&
          viewModel.futureBookings.isEmpty &&
          viewModel.past.isEmpty
      }
  }

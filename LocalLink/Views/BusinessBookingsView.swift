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
        Calendar.current.date(byAdding: .day, value: 1, to: referenceToday)!
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
                    .foregroundColor(AppColors.error)
            }
            
            // Today
            
            if !todayBookings.isEmpty {
                
                Section("Today") {
                    
                    ForEach(todayBookings) { booking in
                        
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
            
            // Tomorrow
            
            if !tomorrowBookings.isEmpty {
                
                Section("Tomorrow") {
                    
                    ForEach(tomorrowBookings) { booking in
                        
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
            
            // Future
            
            if !futureBookings.isEmpty {
                
                Section("Future bookings") {
                    
                    ForEach(futureBookings) { booking in
                        
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
            
            // Past
            
            if !viewModel.past.isEmpty {
                
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
            
            // Empty State
            
            if !viewModel.isLoading &&
                todayBookings.isEmpty &&
                tomorrowBookings.isEmpty &&
                futureBookings.isEmpty &&
                viewModel.past.isEmpty {
                
                ContentUnavailableView(
                    "No bookings yet",
                    systemImage: "calendar",
                    description: Text("New bookings will appear here.")
                )
            }
        }
        .navigationTitle("Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadBookings(for: businessId)
        }
    }
}

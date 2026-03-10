import SwiftUI

struct CustomerBookingsView: View {
    
    @StateObject private var viewModel = CustomerBookingsViewModel()
    @EnvironmentObject private var nav: NavigationState
    
    var body: some View {
        
        List {
            
            // MARK: Loading
            
            if viewModel.isLoading {
                
                HStack {
                    Spacer()
                    ProgressView("Loading bookings…")
                    Spacer()
                }
            }
            
            // MARK: Error
            
            if let error = viewModel.errorMessage {
                
                Text(error)
                    .foregroundColor(AppColors.error)
            }
            
            // MARK: Upcoming
            
            if !viewModel.upcoming.isEmpty {
                
                Section("Upcoming bookings") {
                    
                    ForEach(viewModel.upcoming) { booking in
                        bookingRow(booking)
                    }
                }
            }
            
            // MARK: Past
            
            if !viewModel.past.isEmpty {
                
                Section("Past bookings") {
                    
                    ForEach(viewModel.past) { booking in
                        bookingRow(booking)
                    }
                }
            }
            
            // MARK: Empty
            
            if !viewModel.isLoading &&
                viewModel.upcoming.isEmpty &&
                viewModel.past.isEmpty {
                
                ContentUnavailableView(
                    "No bookings yet",
                    systemImage: "calendar",
                    description: Text("Your upcoming bookings will appear here.")
                )
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .navigationTitle("My Bookings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadBookings()
        }
    }
    
    // MARK: Booking Row
    
    @ViewBuilder
    private func bookingRow(_ booking: Booking) -> some View {
        
        Button {
            
            handleTap(for: booking)
            
        } label: {
            
            ZStack(alignment: .topTrailing) {
                
                BookingRowView(booking: booking)
                
                if booking.unreadCustomerCount > 0 {
                    unreadBadge(count: booking.unreadCustomerCount)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: Tap Behaviour
    
    private func handleTap(for booking: Booking) {
        
        guard let id = booking.id else { return }
        
        // If unread messages → go straight to chat
        
        if booking.unreadCustomerCount > 0 {
            
            nav.path.append(
                AppRoute.bookingDetail(
                    bookingId: id,
                    role: "customer"
                )
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                
                nav.path.append(
                    AppRoute.bookingChat(
                        bookingId: id
                    )
                )
            }
        }
        
        else {
            
            nav.path.append(
                AppRoute.bookingDetail(
                    bookingId: id,
                    role: "customer"
                )
            )
        }
    }
    
    // MARK: Unread Badge
    
    private func unreadBadge(count: Int) -> some View {
        
        Text("\(count)")
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(6)
            .background(AppColors.primary)
            .clipShape(Circle())
            .offset(x: -12, y: 8)
    }
}

import SwiftUI

struct CustomerBookingsView: View {
    
    @StateObject private var viewModel = CustomerBookingsViewModel()
    @EnvironmentObject private var nav: NavigationState
    
    var body: some View {
        List {
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading bookings…")
                    Spacer()
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                .foregroundColor(AppColors.error)            }
            
            if !viewModel.upcoming.isEmpty {
                Section("Upcoming bookings"){
                    ForEach(viewModel.upcoming) { booking in
                        bookingRow(booking)
                    }
                }
            }
            
            if !viewModel.past.isEmpty {
                Section("Past bookings") {
                    ForEach(viewModel.past) { booking in
                        bookingRow(booking)
                    }
                }
            }
            
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
    
    // MARK: - Booking Row
    
    @ViewBuilder
    private func bookingRow(_ booking: Booking) -> some View {
        
        Button(action: {
            guard let id = booking.id else { return }
            nav.path.append(
                AppRoute.bookingDetail(
                    bookingId: id,
                    role: "customer"
                )
            )
        }) {
            ZStack(alignment: .topTrailing) {
                
                BookingRowView(booking: booking)
                
                // 🔴 Unread badge
                if booking.unreadCustomerCount > 0 {
                    unreadBadge(count: booking.unreadCustomerCount)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
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

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingDetailView: View {
    
    let bookingId: String
    let currentUserRole: String   // "customer" or "business"
    
    @State private var booking: Booking?
    @State private var isLoading = true
    @State private var isCancelling = false
    @State private var showCancelConfirm = false
    @State private var errorMessage: String?
    
    @State private var listener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    private let bookingService = BookingService()
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            if isLoading {
                
                ProgressView("Loading booking…")
                
            }
            
            else if let booking {
                
                details(for: booking)
                
                if unreadCount(for: booking) > 0 {
                    newMessageBanner(count: unreadCount(for: booking))
                }
                
                if booking.status == .confirmed {
                    chatButton(for: booking)
                }
                
                if canCancel(booking) {
                    cancelButton(for: booking)
                }
                
            }
            
            else if let errorMessage {
                
                Text(errorMessage)
                    .foregroundColor(AppColors.error)
                
            }
            
            else {
                
                Text("Booking not found")
                    .foregroundColor(.secondary)
                
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }
    
    // MARK: - Unread Messages
    
    private func unreadCount(for booking: Booking) -> Int {
        
        currentUserRole == "customer"
        ? booking.unreadCustomerCount
        : booking.unreadBusinessCount
    }
    
    private func newMessageBanner(count: Int) -> some View {
        
        HStack {
            
            Image(systemName: "message.fill")
            
            Text("You have \(count) new message\(count > 1 ? "s" : "")")
            
        }
        .font(.footnote)
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.primary.opacity(0.15))
        .foregroundColor(AppColors.primary)
        .cornerRadius(10)
    }
    
    // MARK: - Chat
    
    private func chatButton(for booking: Booking) -> some View {
        
        NavigationLink {
            
            BookingChatView(
                bookingId: booking.id ?? "",
                businessId: booking.businessId,
                customerId: booking.customerId,
                currentUserRole: currentUserRole
            )
            
        } label: {
            
            Text("Open Chat")
                .frame(maxWidth: .infinity)
            
        }
        .primaryButton()
    }
    
    // MARK: - Cancel Button
    
    private func cancelButton(for booking: Booking) -> some View {
        
        Button(role: .destructive) {
            
            showCancelConfirm = true
            
        } label: {
            
            if isCancelling {
                ProgressView()
            } else {
                Text("Cancel Booking")
                    .frame(maxWidth: .infinity)
            }
            
        }
        .buttonStyle(.bordered)
        .tint(AppColors.error)
        
        .alert(
            "Cancel Booking?",
            isPresented: $showCancelConfirm
        ) {
            
            Button("Keep Booking", role: .cancel) { }
            
            Button("Cancel Booking", role: .destructive) {
                
                performCancel(booking)
                
            }
            
        } message: {
            
            Text("Are you sure you want to cancel this booking? This action cannot be undone.")
            
        }
    }
    
    // MARK: - Perform Cancel
    
    private func performCancel(_ booking: Booking) {
        
        isCancelling = true
        
        if currentUserRole == "customer" {
            
            bookingService.cancelBookingAsCustomer(
                booking: booking
            ) { result in
                
                DispatchQueue.main.async {
                    
                    isCancelling = false
                    
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            
        } else {
            
            guard let id = booking.id else { return }
            
            bookingService.cancelBookingAsBusiness(
                bookingId: id
            ) { result in
                
                DispatchQueue.main.async {
                    
                    isCancelling = false
                    
                    if case .failure(let error) = result {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Cancel Rules
    
    private func canCancel(_ booking: Booking) -> Bool {
        
        guard booking.status == .confirmed else { return false }
        
        // Customer rule (cannot cancel within 2 hours)
        if currentUserRole == "customer" {
            return booking.startDate > Date().addingTimeInterval(7200)
        }
        
        // Business rule
        return booking.startDate > Date()
    }
    
    // MARK: - Firestore Listener
    
    private func startListening() {
        
        listener = db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snapshot, _ in
                
                guard let snapshot else { return }
                
                self.booking = try? snapshot.data(as: Booking.self)
                self.isLoading = false
            }
    }
    
    private func stopListening() {
        
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Booking Details
    
    private func details(for booking: Booking) -> some View {
        
        VStack(alignment: .leading, spacing: 16) {
            
            Text(booking.safeServiceName)
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)
            
            Divider()
            
            infoRow("Staff", booking.safeStaffName)
            infoRow("Customer", booking.safeCustomerName)
            
            if currentUserRole == "business",
               !booking.safeCustomerAddress.isEmpty {
                
                addressRow(booking.safeCustomerAddress)
            }
            
            infoRow(
                "Date",
                booking.startDate.formatted(date: .long, time: .omitted)
            )
            
            infoRow(
                "Time",
                booking.startDate.formatted(date: .omitted, time: .shortened)
            )
            
            infoRow(
                "Duration",
                "\(booking.serviceDurationMinutes) mins"
            )
            
            infoRow(
                "Price",
                String(format: "£%.2f", Double(booking.price)/100)
            )
            
            statusRow(booking.status)
        }
    }
    // MARK: - Info Row
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        
        HStack {
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
        }
    }
    private func addressRow(_ address: String) -> some View {
        
        Button {
            
            openMaps(address)
            
        } label: {
            
            HStack {
                
                Text("Address")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(address)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(AppColors.primary)
            }
        }
    }
    private func openMaps(_ address: String) {
        
        let encoded = address.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        
        if let url = URL(
            string: "http://maps.apple.com/?q=\(encoded)"
        ) {
            UIApplication.shared.open(url)
        }
    }
    // MARK: - Status Row
    
    private func statusRow(_ status: BookingStatus) -> some View {
        
        HStack {
            
            Text("Status")
                .foregroundColor(.secondary)
            
            Spacer()
            
            statusBadge(for: status)
        }
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(for status: BookingStatus) -> some View {
        
        Text(status.rawValue.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor(status).opacity(0.15))
            .foregroundColor(statusColor(status))
            .cornerRadius(8)
    }
    
    private func statusColor(_ status: BookingStatus) -> Color {
        
        switch status {
            
        case .confirmed:
            return AppColors.success
            
        case .completed:
            return .blue
            
        case .cancelledByBusiness, .cancelledByCustomer:
            return AppColors.error
            
        default:
            return .orange
        }
    }
}

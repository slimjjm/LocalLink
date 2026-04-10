import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingDetailView: View {
    
    let bookingId: String
    let currentUserRole: String
    
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
                
                cancellationPolicyView(for: booking)
                
                if booking.status == .completed {
                    ratingSection(for: booking)
                }
                
                if unreadCount(for: booking) > 0 {
                    newMessageBanner(count: unreadCount(for: booking))
                }
                
                // ✅ Chat allowed during booking
                if booking.status == .confirmed && booking.startDate <= Date() {
                    chatButton(for: booking)
                }
                
                // ✅ Cancel vs Status
                if canCancel(booking) {
                    cancelButton(for: booking)
                } else {
                    bookingStatusView(for: booking)
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
        .alert("Cancel booking?", isPresented: $showCancelConfirm) {
            
            Button("No", role: .cancel) {}
            
            Button("Yes, cancel", role: .destructive) {
                confirmCancel()
            }
            
        } message: {
            Text(cancelMessage())
        }
    }
    
    // MARK: - Cancellation
    
    private func cancelButton(for booking: Booking) -> some View {
        Button {
            showCancelConfirm = true
        } label: {
            if isCancelling {
                ProgressView()
            } else {
                Text(cancelButtonTitle(for: booking))
            }
        }
        .primaryButton()
        .disabled(isCancelling)
    }
    
    private func confirmCancel() {
        guard
            let booking = booking,
            let bookingId = booking.id,
            booking.startDate > Date()
        else { return }
        
        isCancelling = true
        errorMessage = nil
        
        bookingService.cancelBooking(bookingId: bookingId) { result in
            DispatchQueue.main.async {
                isCancelling = false
                
                if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func canCancel(_ booking: Booking) -> Bool {
        booking.status == .confirmed
        && booking.startDate > Date()
        && booking.status != .cancelled_by_business
        && booking.status != .cancelled_by_customer
    }
    
    private func cancelMessage() -> String {
        guard let booking else { return "" }
        
        if currentUserRole == "business" {
            return "This will cancel the booking and refund the customer."
        }
        
        return hoursUntilBooking(booking) >= 24
        ? "You will receive a full refund."
        : "This booking is less than 24 hours away and is non-refundable."
    }
    
    private func cancelButtonTitle(for booking: Booking) -> String {
        if currentUserRole == "business" { return "Cancel & Refund" }
        
        return hoursUntilBooking(booking) >= 24
        ? "Cancel & Refund"
        : "Cancel (No Refund)"
    }
    
    private func hoursUntilBooking(_ booking: Booking) -> Double {
        booking.startDate.timeIntervalSinceNow / 3600
    }
    
    // MARK: - Status (FIXED)
    
    @ViewBuilder
    private func bookingStatusView(for booking: Booking) -> some View {

        if booking.status == .cancelled_by_business || booking.status == .cancelled_by_customer {
            statusPill(text: "Cancelled", color: .red)
        }
        else if booking.startDate <= Date() && booking.endDate >= Date() {
            statusPill(text: "In progress", color: .orange)
        }
        else if booking.endDate < Date() {
            VStack(spacing: 10) {
                statusPill(text: "Completed", color: .green)

                Button("Book again") {
                    // TODO: navigate
                }
                .primaryButton()
            }
        }
    }
    
    private func statusPill(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(10)
    }
    
    // MARK: - Cancellation Policy
    
    private func cancellationPolicyView(for booking: Booking) -> some View {
        
        let deadline = Calendar.current.date(byAdding: .hour, value: -24, to: booking.startDate) ?? booking.startDate
        let isPast = Date() > deadline
        
        return VStack(alignment: .leading, spacing: 6) {
            
            Text("Cancellation policy")
                .font(.headline)
            
            if currentUserRole == "business" {
                Text("If you cancel, the customer will receive a full refund.")
                    .foregroundColor(.secondary)
            } else {
                Text(
                    isPast
                    ? "This booking is now non-refundable."
                    : "Free cancellation until \(dateFormatter.string(from: deadline))"
                )
                .foregroundColor(isPast ? AppColors.error : AppColors.success)
            }
        }
        .padding()
        .background(AppColors.primary.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
    
    // MARK: - Rating
    
    private func ratingSection(for booking: Booking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("How was your experience?")
                .font(.headline)
            
            if booking.rating != nil {
                Text("Thanks for your feedback 👍")
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Button("👍 Good") {
                        submitRating(booking: booking, value: "up")
                    }
                    Button("👎 Bad") {
                        submitRating(booking: booking, value: "down")
                    }
                }
            }
        }
    }
    
    private func submitRating(booking: Booking, value: String) {
        guard let id = booking.id else { return }

        let bookingRef = db.collection("bookings").document(id)
        let businessRef = db.collection("businesses").document(booking.businessId)

        db.runTransaction({ transaction, errorPointer in
            do {
                let bookingSnap = try transaction.getDocument(bookingRef)

                if bookingSnap.data()?["rating"] != nil {
                    return nil
                }

                transaction.updateData([
                    "rating": value,
                    "ratedAt": FieldValue.serverTimestamp()
                ], forDocument: bookingRef)

                let field = value == "up" ? "ratingPositiveCount" : "ratingNegativeCount"

                transaction.updateData([
                    field: FieldValue.increment(Int64(1))
                ], forDocument: businessRef)

            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            return nil
        }) { _, error in
            if let error {
                print("Rating failed:", error)
            } else {
                print("Rating success")
            }
        }
    }
    
    // MARK: - Chat
    
    private func unreadCount(for booking: Booking) -> Int {
        currentUserRole == "customer"
        ? booking.unreadCustomerCount
        : booking.unreadBusinessCount
    }
    
    private func newMessageBanner(count: Int) -> some View {
        Text("You have \(count) new message(s)")
            .padding()
            .background(AppColors.primary.opacity(0.15))
            .cornerRadius(10)
    }
    
    private func chatButton(for booking: Booking) -> some View {
        NavigationLink("Open Chat") {
            EnquiryChatView(
                businessId: booking.businessId,
                customerId: booking.customerId
            )
        }
        .primaryButton()
    }
    
    // MARK: - Firestore
    
    private func startListening() {
        listener = db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snapshot, _ in
                self.booking = try? snapshot?.data(as: Booking.self)
                self.isLoading = false
            }
    }
    
    private func stopListening() {
        listener?.remove()
    }
    
    // MARK: - Details
    
    private func details(for booking: Booking) -> some View {
        VStack(alignment: .leading) {
            Text(booking.safeServiceName)
            Text(booking.safeStaffName)
        }
    }
}

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
                
                if booking.status == .completed {
                    ratingSection(for: booking)
                }
                
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

                let field = value == "up"
                    ? "ratingPositiveCount"
                    : "ratingNegativeCount"

                transaction.updateData([
                    field: FieldValue.increment(Int64(1))
                ], forDocument: businessRef)

            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            return nil

        }) { _, error in

            if let error = error {
                print("Rating failed:", error)
            } else {
                print("Rating success")
            }
        }
    }
    // MARK: - Helpers
    
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
            BookingChatView(
                bookingId: booking.id ?? "",
                businessId: booking.businessId,
                customerId: booking.customerId,
                currentUserRole: currentUserRole
            )
        }
        .primaryButton()
    }
    
    private func cancelButton(for booking: Booking) -> some View {
        Button("Cancel Booking", role: .destructive) {
            performCancel(booking)
        }
    }
    
    private func performCancel(_ booking: Booking) {
        isCancelling = true
    }
    
    private func canCancel(_ booking: Booking) -> Bool {
        booking.status == .confirmed
    }
    
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
    
    private func details(for booking: Booking) -> some View {
        VStack(alignment: .leading) {
            Text(booking.safeServiceName)
            Text(booking.safeStaffName)
        }
    }
}

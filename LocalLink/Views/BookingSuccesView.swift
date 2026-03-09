import SwiftUI
import FirebaseFirestore

struct BookingSuccessView: View {
    
    let businessId: String
    let bookingId: String
    
    @EnvironmentObject private var nav: NavigationState
    
    @State private var serviceArea: String = ""
    @State private var bookingConfirmed = false
    @State private var listener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 28) {
            
            Image(systemName: bookingConfirmed ? "checkmark.circle.fill" : "clock.badge.checkmark.fill")
                .font(.system(size: 72))
                .foregroundColor(bookingConfirmed ? AppColors.success : AppColors.primary)
            
            VStack(spacing: 10) {
                
                Text(bookingConfirmed ? "Booking confirmed" : "Processing booking…")
                    .font(.largeTitle.bold())
                    .foregroundColor(AppColors.charcoal)
                
                if !serviceArea.isEmpty {
                    Label(serviceArea, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(
                    bookingConfirmed
                    ? "Your booking has been successfully confirmed."
                    : "We’re finalising your booking and syncing payment confirmation."
                )
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                
                Text(
                    bookingConfirmed
                    ? "Taking you back to My Bookings…"
                    : "This should only take a moment."
                )
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                nav.path.append(.customerHome)
            } label: {
                Text("Go to My Bookings")
                    .frame(maxWidth: .infinity)
            }
            .primaryButton()
        }
        .padding()
        .background(AppColors.background)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            loadBusiness()
            startBookingListener()
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }
    
    // MARK: - Booking Listener
    
    private func startBookingListener() {
        
        guard !bookingId.isEmpty else { return }
        
        listener?.remove()
        
        listener = db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snapshot, error in
                
                guard error == nil else { return }
                guard let data = snapshot?.data() else { return }
                
                let status = data["status"] as? String ?? ""
                
                if status == "confirmed" && !bookingConfirmed {
                    DispatchQueue.main.async {
                        bookingConfirmed = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            nav.path.append(.customerHome)
                        }
                    }
                }
            }
    }
    
    // MARK: - Load Business
    
    private func loadBusiness() {
        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.serviceArea = snapshot?.data()?["serviceArea"] as? String ?? ""
                }
            }
    }
}

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

@MainActor
final class CustomerBookingsViewModel: ObservableObject {
    
    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    func loadBookings() {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("bookings")
            .whereField("customerId", isEqualTo: uid)
            .order(by: "startDate")
            .getDocuments { [weak self] snapshot, error in
                
                guard let self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error {
                        print("❌ BOOKINGS ERROR:", error.localizedDescription)
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    
                    // ✅ DECODE ONCE
                    let bookings = snapshot?.documents.compactMap {
                        try? $0.data(as: Booking.self)
                    } ?? []
                    
                    // 🔥 DEBUG PRINT WHAT FIRESTORE ACTUALLY RETURNED
                    for b in bookings {
                        print("🔥 FIRESTORE STATUS:", b.status)
                    }
                    
                    let now = Date()
                    
                    // TEMPORARY – DO NOT FILTER BY STATUS YET
                    self.upcoming = bookings
                        .filter {
                            $0.endDate >= now
                        }
                        .sorted { $0.startDate < $1.startDate }
                    
                    self.past = bookings
                        .filter {
                            $0.endDate < now
                        }
                        .sorted { $0.startDate > $1.startDate }
                }
            }
    }
}

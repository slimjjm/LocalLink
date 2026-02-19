import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class CustomerBookingsViewModel: ObservableObject {
    
    @Published var upcoming: [Booking] = []
    @Published var past: [Booking] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    func loadBookings() {
        guard let customerId = Auth.auth().currentUser?.uid else {
            errorMessage = "Not logged in"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        db.collection("bookings")
            .whereField("customerId", isEqualTo: customerId)
            .order(by: "startDate", descending: false)
            .getDocuments { [weak self] snapshot, error in
                
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error {
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    let bookings = snapshot?.documents.compactMap {
                        try? $0.data(as: Booking.self)
                    } ?? []
                    
                    let now = Date()
                    
                    // UPCOMING = confirmed AND not yet ended
                    self?.upcoming = bookings
                        .filter {
                            $0.status == .confirmed &&
                            $0.endDate >= now
                        }
                        .sorted { $0.startDate < $1.startDate }
                    
                    // PAST = explicitly completed / refunded / cancelled
                    self?.past = bookings
                        .filter {
                            $0.status == .completed ||
                            $0.status == .refunded ||
                            $0.status == .cancelledByBusiness
                        }
                        .sorted { $0.startDate > $1.startDate }
                }
            }
    }
}


import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class ChatUnreadViewModel: ObservableObject {
    
    @Published var totalUnread: Int = 0
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // MARK: - Start Listening
    
    func startListening(role: String, businessId: String? = nil) {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Remove existing listener
        listener?.remove()
        
        let query: Query
        
        // ✅ CUSTOMER
        if role == "customer" {
            
            query = db.collection("businessChats")
                .whereField("customerId", isEqualTo: uid)
            
        // ✅ BUSINESS
        } else {
            
            guard let businessId else {
                print("❌ Missing businessId for business unread listener")
                return
            }
            
            query = db.collection("businessChats")
                .whereField("businessId", isEqualTo: businessId)
        }
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            
            if let error {
                print("❌ Unread listener error:", error.localizedDescription)
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            var total = 0
            
            for doc in documents {
                
                let data = doc.data()
                
                let unread = role == "customer"
                    ? data["unreadForCustomer"] as? Int ?? 0
                    : data["unreadForBusiness"] as? Int ?? 0
                
                total += unread
            }
            
            DispatchQueue.main.async {
                self?.totalUnread = total
            }
        }
    }
    
    // MARK: - Stop Listening
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

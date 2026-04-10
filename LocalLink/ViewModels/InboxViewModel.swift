import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class InboxViewModel: ObservableObject {
    
    @Published var conversations: [Conversation] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // MARK: - Start Listening
    
    func startListening(role: String, businessId: String) {
        
        guard let user = Auth.auth().currentUser else { return }
        
        // 🚫 Block anonymous users
        guard !user.isAnonymous else {
            conversations = []
            return
        }
        
        stopListening()
        
        let query: Query
        
        if role == "customer" {
            query = db.collection("businessChats")
                .whereField("customerId", isEqualTo: user.uid)
        } else {
            query = db.collection("businessChats")
                .whereField("businessId", isEqualTo: businessId)
        }
        
        listener = query
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                
                if let error {
                    print("❌ Inbox error:", error.localizedDescription)
                    return
                }
                
                guard let docs = snapshot?.documents else {
                    self?.conversations = []
                    return
                }
                
                let convos = docs.compactMap { doc -> Conversation? in
                    
                    let data = doc.data()
                    
                    guard
                        let businessId = data["businessId"] as? String,
                        let customerId = data["customerId"] as? String
                    else { return nil }
                    
                    let title: String
                    let unreadCount: Int
                    
                    if role == "customer" {
                        title = data["businessName"] as? String ?? "Business"
                        unreadCount = data["unreadForCustomer"] as? Int ?? 0
                    } else {
                        title = data["customerName"] as? String ?? "Customer"
                        unreadCount = data["unreadForBusiness"] as? Int ?? 0
                    }
                    
                    return Conversation(
                        id: doc.documentID,
                        businessId: businessId,
                        customerId: customerId,
                        title: title,
                        lastMessage: data["lastMessage"] as? String ?? "",
                        timestamp: (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date(),
                        unreadCount: unreadCount
                    )
                }
                
                DispatchQueue.main.async {
                    self?.conversations = convos
                }
            }
    }
    
    // MARK: - Stop
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

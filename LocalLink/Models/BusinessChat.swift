import Foundation
import FirebaseFirestore

struct BusinessChat: Identifiable {
    
    let id: String
    let businessId: String
    let customerId: String
    let previewName: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
    
    init?(document: QueryDocumentSnapshot, role: String) {
        
        let data = document.data()
        
        guard
            let businessId = data["businessId"] as? String,
            let customerId = data["customerId"] as? String,
            let lastMessage = data["lastMessage"] as? String
        else { return nil }
        
        self.id = document.documentID
        self.businessId = businessId
        self.customerId = customerId
        self.lastMessage = lastMessage
        
        // 👇 name logic
        if role == "customer" {
            self.previewName = data["businessName"] as? String ?? "Business"
        } else {
            self.previewName = data["customerName"] as? String ?? "Customer"
        }
        
        // 👇 timestamp
        self.timestamp = (data["lastMessageAt"] as? Timestamp)?.dateValue() ?? Date()
        
        // 👇 unread logic (THIS IS KEY)
        if role == "customer" {
            self.unreadCount = data["unreadForCustomer"] as? Int ?? 0
        } else {
            self.unreadCount = data["unreadForBusiness"] as? Int ?? 0
        }
    }
}

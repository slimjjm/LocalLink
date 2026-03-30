import Foundation
import FirebaseFirestore

struct BusinessChat: Identifiable {
    
    let id: String
    let businessId: String
    let customerId: String
    let lastMessage: String
    let unreadCount: Int
    
    var previewName: String {
        "Customer" // 🔥 upgrade later with real names
    }
    
    init?(document: QueryDocumentSnapshot) {
        
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
        self.unreadCount = data["unreadForBusiness"] as? Int ?? 0
    }
}

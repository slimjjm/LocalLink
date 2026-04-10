import Foundation
import FirebaseFirestore
import FirebaseAuth

struct ChatMessage: Identifiable {
    
    let id: String
    let text: String
    let senderId: String
    let senderName: String
    let senderRole: String   // 🔥 NEW
    let createdAt: Date?
    
    // 🔥 IMPROVED identity check (more reliable)
    var isFromCurrentUser: Bool {
        let currentUID = Auth.auth().currentUser?.uid
        let isMatch = senderId == currentUID
        
        print("🧠 ID CHECK:")
        print("   senderId:", senderId)
        print("   currentUser:", currentUID ?? "nil")
        print("   match:", isMatch)
        
        return isMatch
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard
            let text = data["text"] as? String,
            let senderId = data["senderId"] as? String
        else {
            print("❌ Failed to decode message:", data)
            return nil
        }
        
        self.id = document.documentID
        self.text = text
        self.senderId = senderId
        self.senderName = data["senderName"] as? String ?? "User"
        self.senderRole = data["senderRole"] as? String ?? "customer" // 🔥 NEW
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        
        print("✅ Message decoded:")
        print("   text:", text)
        print("   senderRole:", senderRole)
    }
}

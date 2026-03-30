import Foundation
import FirebaseFirestore
import FirebaseAuth

struct ChatMessage: Identifiable {
    
    let id: String
    let text: String
    let senderId: String
    
    var isFromCurrentUser: Bool {
        return senderId == Auth.auth().currentUser?.uid
    }
    
    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        
        guard
            let text = data["text"] as? String,
            let senderId = data["senderId"] as? String
        else { return nil }
        
        self.id = document.documentID
        self.text = text
        self.senderId = senderId
    }
}

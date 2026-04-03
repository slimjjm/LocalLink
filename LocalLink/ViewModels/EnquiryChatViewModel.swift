import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class EnquiryChatViewModel: ObservableObject {
    
    @Published var messages: [ChatMessage] = []
    
    private let db = Firestore.firestore()
    
    private var chatId: String?
    private var listener: ListenerRegistration?
    
    private var role: String = "customer"
    private var businessId: String = ""
    
    // MARK: - START
    
    func start(businessId: String, role: String) {
        
        guard let user = Auth.auth().currentUser else { return }
        
        self.role = role
        self.businessId = businessId
        
        let id = "\(businessId)_\(user.uid)"
        self.chatId = id
        
        let chatRef = db.collection("businessChats").document(id)
        
        chatRef.getDocument { snapshot, _ in
            
            if snapshot?.exists == false {
                
                chatRef.setData([
                    "businessId": businessId,
                    "customerId": user.uid,
                    "lastMessage": "Hi, I'm interested in your services",
                    "lastMessageAt": Timestamp(),
                    "unreadForBusiness": 0,
                    "unreadForCustomer": 0
                ])
            }
        }
        
        listen()
    }
    
    // MARK: - LISTEN
    
    private func listen() {
        
        guard let chatId else { return }
        
        listener?.remove()
        
        listener = db.collection("businessChats")
            .document(chatId)
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let self else { return }
                
                self.messages = snapshot?.documents.compactMap {
                    ChatMessage(document: $0)
                } ?? []
            }
    }
    
    // MARK: - SEND
    
    func send(text: String) {
        
        guard let user = Auth.auth().currentUser,
              let chatId else { return }
        
        let messageRef = db.collection("businessChats")
            .document(chatId)
            .collection("messages")
            .document()
        
        let senderRole = role
        
        let data: [String: Any] = [
            "senderId": user.uid,
            "senderRole": senderRole,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        messageRef.setData(data)
        
        // 🔥 KEY LOGIC
        
        var update: [String: Any] = [
            "lastMessage": text,
            "lastMessageAt": FieldValue.serverTimestamp()
        ]
        
        if senderRole == "customer" {
            update["unreadForBusiness"] = FieldValue.increment(Int64(1))
        } else {
            update["unreadForCustomer"] = FieldValue.increment(Int64(1))
        }
        
        db.collection("businessChats")
            .document(chatId)
            .updateData(update)
    }
    
    // MARK: - MARK AS READ
    
    func markAsRead() {
        
        guard let chatId else { return }
        
        let field = role == "customer"
        ? "unreadForCustomer"
        : "unreadForBusiness"
        
        db.collection("businessChats")
            .document(chatId)
            .updateData([
                field: 0
            ])
    }
}

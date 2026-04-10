import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class EnquiryChatViewModel: ObservableObject {
    
    @Published var messages: [ChatMessage] = []
    @Published var errorMessage: String? // 🔥 NEW (for TestFlight debugging)
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    private var chatId: String?
    private var businessId: String?
    private var customerId: String?
    private var role: String = "customer"
    private var businessName: String = "Business"
    
    // MARK: - START
    
    func start(businessId: String, customerId: String? = nil, role: String) {
        
        print("🚀 START CHAT CALLED")
        print("   businessId: \(businessId)")
        print("   role: \(role)")
        
        guard let user = Auth.auth().currentUser else {
            print("❌ No user logged in")
            return
        }
        
        guard !user.isAnonymous else {
            print("❌ Guest users cannot use enquiry chat")
            return
        }
        
        listener?.remove()
        messages = []
        
        self.businessId = businessId
        self.role = role
        
        if role == "customer" {
            self.customerId = user.uid
        } else {
            guard let customerId else {
                print("❌ Missing customerId for business")
                return
            }
            self.customerId = customerId
        }
        
        guard let resolvedCustomerId = self.customerId else {
            print("❌ Could not resolve customerId")
            return
        }
        
        self.chatId = "\(businessId)_\(resolvedCustomerId)"
        
        print("✅ ChatID: \(self.chatId ?? "nil")")
        
        Task {
            do {
                try await loadBusinessName()
                try await ensureChatExists()
                listen()
                markAsRead()
            } catch {
                print("❌ Failed to start chat: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - LOAD BUSINESS NAME
    
    private func loadBusinessName() async throws {
        
        guard let businessId else { return }
        
        print("🏷 Loading business name...")
        
        let snapshot = try await db.collection("businesses").document(businessId).getDocument()
        
        if let name = snapshot.data()?["businessName"] as? String {
            businessName = name
        }
        
        print("✅ Business name: \(businessName)")
    }
    
    // MARK: - ENSURE CHAT EXISTS
    
    private func ensureChatExists() async throws {
        
        guard let chatId,
              let businessId,
              let customerId,
              let user = Auth.auth().currentUser else { return }
        
        print("📂 Ensuring chat exists / syncing...")
        
        let ref = db.collection("businessChats").document(chatId)
        
        let userDoc = try await db.collection("users").document(user.uid).getDocument()
        let customerName = userDoc.data()?["name"] as? String ?? "Customer"
        
        try await ref.setData([
            "businessId": businessId,
            "customerId": customerId, // 🔥 FORCE CORRECT UID
            "customerName": customerName,
            "businessName": businessName,
            "lastMessage": "",
            "lastMessageAt": FieldValue.serverTimestamp(),
            "unreadForCustomer": 0,
            "unreadForBusiness": 0
        ], merge: true)
    }
    
    // MARK: - LISTEN
    
    private func listen() {
        
        guard let chatId else { return }
        
        print("👂 LISTEN STARTED")
        print("   path: businessChats/\(chatId)/messages")
        
        listener?.remove()
        
        listener = db.collection("businessChats")
            .document(chatId)
            .collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                
                if let error {
                    print("❌ Listen error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.errorMessage = error.localizedDescription
                    }
                    return
                }
                
                guard let docs = snapshot?.documents else {
                    print("⚠️ No documents")
                    self?.messages = []
                    return
                }
                
                print("📨 Snapshot received: \(docs.count) messages")
                
                let mapped = docs.compactMap { ChatMessage(document: $0) }
                
                self?.messages = mapped
            }
    }
    
    // MARK: - SEND
    
    func send(text: String) {
        
        print("🚀 send() CALLED")
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            print("⚠️ Empty message")
            return
        }
        
        guard let user = Auth.auth().currentUser,
              let chatId,
              let businessId,
              let customerId else {
            print("❌ Missing context")
            return
        }
        
        let uid = user.uid
        let isCustomer = role == "customer"
        
        print("📦 Sending:")
        print("   chatId: \(chatId)")
        print("   text: \(trimmed)")
        
        let chatRef = db.collection("businessChats").document(chatId)
        let messageRef = chatRef.collection("messages").document()
        
        let batch = db.batch()
        
        Task {
            do {
                // 🔥 FETCH REAL NAME FROM USERS COLLECTION
                let userDoc = try await db.collection("users").document(uid).getDocument()
                let customerName = userDoc.data()?["name"] as? String ?? "Customer"
                
                let senderName = isCustomer ? customerName : businessName
                
                // ✅ MESSAGE
                batch.setData([
                    "senderId": uid,
                    "senderRole": role,
                    "senderName": senderName,
                    "text": trimmed,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: messageRef)
                
                // ✅ CHAT METADATA
                batch.setData([
                    "businessId": businessId,
                    "customerId": customerId,
                    "customerName": customerName, // 🔥 NOW CORRECT
                    "businessName": businessName,
                    "lastMessage": trimmed,
                    "lastMessageAt": FieldValue.serverTimestamp(),
                    "unreadForCustomer": isCustomer ? 0 : FieldValue.increment(Int64(1)),
                    "unreadForBusiness": isCustomer ? FieldValue.increment(Int64(1)) : 0
                ], forDocument: chatRef, merge: true)
                
                batch.commit { [weak self] error in
                    if let error {
                        print("❌ SEND FAILED: \(error.localizedDescription)")
                        
                        DispatchQueue.main.async {
                            self?.errorMessage = error.localizedDescription
                        }
                        
                    } else {
                        print("✅ SEND SUCCESS")
                        
                        DispatchQueue.main.async {
                            self?.errorMessage = nil
                        }
                    }
                }
                
            } catch {
                print("❌ Failed to fetch user name: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - READ
    
    func markAsRead() {
        
        guard let chatId else {
            print("❌ markAsRead: Missing chatId")
            return
        }
        
        print("👁 Marking as read for chatId:", chatId)
        
        let ref = db.collection("businessChats").document(chatId)
        
        if role == "customer" {
            ref.updateData(["unreadForCustomer": 0])
        } else {
            ref.updateData(["unreadForBusiness": 0])
        }
    }
    
    // MARK: - STOP
    
    func stopListening() {
        print("🛑 Listener stopped")
        
        listener?.remove()
        listener = nil
    }
}

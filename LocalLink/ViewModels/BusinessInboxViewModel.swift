import Foundation
import FirebaseFirestore

@MainActor
final class BusinessInboxViewModel: ObservableObject {
    
    @Published var chats: [BusinessChat] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func start(businessId: String) {
        
        listener?.remove()
        
        listener = db.collection("businessChats")
            .whereField("businessId", isEqualTo: businessId)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                
                if let error {
                    print("❌ Business inbox error:", error.localizedDescription)
                    return
                }
                
                guard let docs = snapshot?.documents else { return }
                
                let chats: [BusinessChat] = docs.compactMap { doc in
                    BusinessChat(document: doc, role: "business")
                }
                DispatchQueue.main.async {
                    self?.chats = chats
                }
            }
    }
    
    func stop() {
        listener?.remove()
        listener = nil
    }
}

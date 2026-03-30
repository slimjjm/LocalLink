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
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let self else { return }
                
                self.chats = snapshot?.documents.compactMap {
                    BusinessChat(document: $0)
                } ?? []
            }
    }
}

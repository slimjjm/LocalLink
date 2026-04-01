import Foundation
import FirebaseFirestore
import FirebaseAuth

final class InboxViewModel: ObservableObject {
    
    @Published var conversations: [Conversation] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func startListening() {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        listener = db.collection("bookings")
            .whereField("customerId", isEqualTo: uid)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                
                guard let self else { return }
                guard let docs = snapshot?.documents else { return }
                
                var temp: [Conversation] = []
                let group = DispatchGroup()
                
                for doc in docs {
                    
                    let data = doc.data()
                    let bookingId = doc.documentID
                    
                    let title = data["serviceName"] as? String ?? "Business"
                    let unread = data["unreadForCustomer"] as? Int ?? 0
                    
                    group.enter()
                    
                    self.db.collection("bookings")
                        .document(bookingId)
                        .collection("messages")
                        .order(by: "createdAt", descending: true)
                        .limit(to: 1)
                        .getDocuments { snap, _ in
                            
                            defer { group.leave() }
                            
                            let lastDoc = snap?.documents.first
                            
                            let text = lastDoc?.data()["text"] as? String ?? "Start conversation"
                            let timestamp = (lastDoc?.data()["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                            
                            temp.append(
                                Conversation(
                                    id: bookingId,
                                    bookingId: bookingId,
                                    title: title,
                                    lastMessage: text,
                                    timestamp: timestamp,
                                    unreadCount: unread
                                )
                            )
                        }
                }
                
                group.notify(queue: .main) {
                    self.conversations = temp.sorted { $0.timestamp > $1.timestamp }
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

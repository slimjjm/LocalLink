import Foundation
import FirebaseFirestore
import FirebaseAuth

struct ChatPreview: Identifiable {
    let id: String
    let bookingId: String
    let title: String
    let lastMessage: String
    let unreadCount: Int
    let timestamp: Date
}

@MainActor
final class ChatUnreadViewModel: ObservableObject {
    
    @Published var totalUnread: Int = 0
    @Published var recentChats: [ChatPreview] = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func startListening(role: String, businessId: String?) {
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        listener?.remove()
        
        let query: Query
        
        if role == "customer" {
            query = db.collection("bookings")
                .whereField("customerId", isEqualTo: uid)
        } else {
            guard let businessId else { return }
            query = db.collection("bookings")
                .whereField("businessId", isEqualTo: businessId)
        }
        
        listener = query.addSnapshotListener { [weak self] snapshot, error in
            if let error {
                print("❌ Chat unread listener error:", error)
                return
            }

            guard let documents = snapshot?.documents else { return }

            Task {
                await self?.processBookings(documents: documents, role: role)
            }
        }
    }

    // 🔥 NEW — ASYNC PROCESSING
    private func processBookings(documents: [QueryDocumentSnapshot], role: String) async {

        var total = 0
        var chats: [ChatPreview] = []

        for doc in documents {
            
            let data = doc.data()
            let bookingId = doc.documentID
            
            let unread = role == "customer"
                ? data["unreadForCustomer"] as? Int ?? 0
                : data["unreadForBusiness"] as? Int ?? 0
            
            total += unread
            
            let title: String = {
                if role == "customer" {
                    return data["businessName"] as? String ?? "Business"
                } else {
                    return data["customerName"] as? String ?? "Customer"
                }
            }()
            
            // 🔥 FETCH LAST MESSAGE
            let lastMessageData = await fetchLastMessage(bookingId: bookingId)
            
            let lastMessage = lastMessageData?.text ?? "Start conversation"
            let timestamp = lastMessageData?.createdAt ?? Date.distantPast
            
            chats.append(
                ChatPreview(
                    id: bookingId,
                    bookingId: bookingId,
                    title: title,
                    lastMessage: lastMessage,
                    unreadCount: unread,
                    timestamp: timestamp
                )
            )
        }

        chats.sort { $0.timestamp > $1.timestamp }

        self.totalUnread = total
        self.recentChats = chats
    }

    // 🔥 NEW — FETCH LAST MESSAGE
    private func fetchLastMessage(bookingId: String) async -> BookingMessage? {
        
        do {
            let snapshot = try await db
                .collection("bookings")
                .document(bookingId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()
            
            return snapshot.documents.first.flatMap {
                try? $0.data(as: BookingMessage.self)
            }
            
        } catch {
            print("❌ Failed to fetch last message:", error)
            return nil
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

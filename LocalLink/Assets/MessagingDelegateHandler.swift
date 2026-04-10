import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

final class MessagingDelegateHandler: NSObject, MessagingDelegate {

    static let shared = MessagingDelegateHandler()
    private let db = Firestore.firestore()
    
    // 🔥 Store token if user not ready yet
    private var pendingToken: String?

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        
        guard let token = fcmToken else { return }
        
        print("🔥 FCM Token received:", token)

        pendingToken = token
        saveTokenIfPossible(token)
    }

    func saveTokenIfPossible(_ token: String) {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No user yet — storing token for later")
            pendingToken = token
            return
        }

        db.collection("users")
            .document(uid)
            .setData([
                "fcmTokens": FieldValue.arrayUnion([token])
            ], merge: true)

        print("✅ FCM Token saved for user:", uid)
        
        pendingToken = nil
    }
    
    // 🔥 CALL THIS AFTER LOGIN
    func flushPendingTokenIfNeeded() {
        
        guard let token = pendingToken else { return }
        
        print("🔄 Flushing pending token...")
        saveTokenIfPossible(token)
    }
}

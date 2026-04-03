import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore
import UserNotifications

// =================================================
// MARK: - FCM TOKEN HANDLER
// =================================================

final class MessagingDelegateHandler: NSObject, MessagingDelegate {

    static let shared = MessagingDelegateHandler()
    private let db = Firestore.firestore()

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        
        guard let token = fcmToken else { return }
        
        print("🔥 FCM Token received:", token)

        saveTokenIfPossible(token)
    }

    // 🔥 Call this ALSO after login if needed
    func saveTokenIfPossible(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ No user logged in yet — token will be saved later")
            return
        }

        db.collection("users")
            .document(uid)
            .setData([
                "fcmTokens": FieldValue.arrayUnion([token])
            ], merge: true)

        print("✅ FCM Token saved for user:", uid)
    }
}

// =================================================
// MARK: - NOTIFICATION HANDLER
// =================================================

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    // ✅ Show notification while app is open
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // ✅ Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {

        let userInfo = response.notification.request.content.userInfo

        // 🔥 SAFE PARSING (important)
        let bookingId =
            userInfo["bookingId"] as? String ??
            (userInfo["data"] as? [String: Any])?["bookingId"] as? String

        if let bookingId {
            DispatchQueue.main.async {
                NotificationRouter.shared.bookingIdToOpen = bookingId
            }
        }

        completionHandler()
    }
}

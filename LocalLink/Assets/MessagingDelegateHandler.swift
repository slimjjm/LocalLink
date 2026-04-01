import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

final class MessagingDelegateHandler: NSObject, MessagingDelegate {

    static let shared = MessagingDelegateHandler()
    private let db = Firestore.firestore()

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

        guard let token = fcmToken else { return }

        print("🔥 FCM Token:", token)

        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No user logged in, skipping FCM save")
            return
        }

        db.collection("users")
            .document(uid)
            .setData([
                "fcmTokens": FieldValue.arrayUnion([token])
            ], merge: true)

        print("✅ FCM Token saved:", token)
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // 👇 ADD THIS (CRITICAL)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {

        let userInfo = response.notification.request.content.userInfo

        if let bookingId = userInfo["bookingId"] as? String {
            DispatchQueue.main.async {
                NotificationRouter.shared.bookingIdToOpen = bookingId
            }
        }

        completionHandler()
    }
}

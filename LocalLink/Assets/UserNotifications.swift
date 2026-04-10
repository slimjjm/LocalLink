import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = NotificationManager()
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("Notifications granted: \(granted)")
            if let error {
                print("❌ Notification permission error:", error)
            }
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
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

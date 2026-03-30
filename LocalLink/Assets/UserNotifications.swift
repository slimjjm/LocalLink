import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("Notifications granted: \(granted)")
        }
    }
}

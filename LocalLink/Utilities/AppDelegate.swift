import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import GoogleSignIn
import StripePaymentSheet

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        FirebaseApp.configure()

        // =================================================
        // MARK: - Notifications Setup
        // =================================================

        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        Messaging.messaging().token { token, error in
            if let token = token {
                print("🔥 FCM Token (launch fetch):", token)
                MessagingDelegateHandler.shared.saveTokenIfPossible(token)
            }
        }

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("🔔 Notifications granted:", granted)
            if let error {
                print("❌ Notification permission error:", error)
            }
        }

        application.registerForRemoteNotifications()

        // =================================================
        // MARK: - FCM Setup
        // =================================================

        Messaging.messaging().delegate = MessagingDelegateHandler.shared

        // =================================================
        // MARK: - Handle Launch From Notification
        // =================================================

        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            
            let bookingId =
                notification["bookingId"] as? String ??
                (notification["data"] as? [String: Any])?["bookingId"] as? String

            if let bookingId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    NotificationRouter.shared.bookingIdToOpen = bookingId
                }
            }
        }

        return true
    }

    // =================================================
    // MARK: - APNs → Firebase
    // =================================================

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for notifications:", error)
    }

    // =================================================
    // MARK: - Google Sign-In
    // =================================================

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

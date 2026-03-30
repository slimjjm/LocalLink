import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import GoogleSignIn
import Stripe

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        if let notification = launchOptions?[.remoteNotification] as? [AnyHashable: Any],
           let bookingId = notification["bookingId"] as? String {

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NotificationRouter.shared.bookingIdToOpen = bookingId
            }
        }
        FirebaseApp.configure()

        // ✅ Ask permission ONCE (correct place)
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            print("Notifications granted: \(granted)")
        }

        application.registerForRemoteNotifications()

        // ✅ FCM setup
        Messaging.messaging().delegate = MessagingDelegateHandler.shared

        // ✅ Stripe
        StripeAPI.defaultPublishableKey = "pk_live_..."

        return true
    }

    // ✅ REQUIRED: APNs → Firebase
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // ✅ Optional (good for debugging)
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for notifications:", error)
    }

    // ✅ Google Sign-In
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

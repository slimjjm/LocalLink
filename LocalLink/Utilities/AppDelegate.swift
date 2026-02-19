import UIKit
import Firebase
import GoogleSignIn
import Stripe

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        // Firebase
        FirebaseApp.configure()

        // Stripe
        StripeAPI.defaultPublishableKey = "pk_test_51SglXq2fXPPaIIVVjyW1MvaYm3owf9CBHeVGJILTn41zd3d3OX59fzYPZ5ZeIqtkXBoyyJGB9z0JQNg0D5vo0CqK00YFUZVaj3"

        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}



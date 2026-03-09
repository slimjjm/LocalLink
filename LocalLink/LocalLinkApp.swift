import SwiftUI
import FirebaseCore
import GoogleSignIn
import Stripe
import StripePayments

@main
struct LocalLinkApp: App {

    // Needed for Google Sign-In + Firebase
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()

    init() {
        // Configure Stripe with your TEST publishable key
        StripeAPI.defaultPublishableKey = "pk_test_51SglXq2fXPPaIIVVjyW1MvaYm3owf9CBHeVGJILTn41zd3d3OX59fzYPZ5ZeIqtkXBoyyJGB9z0JQNg0D5vo0CqK00YFUZVaj3"
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(nav)
                .environmentObject(authManager)
        }
    }
}

import SwiftUI
import FirebaseCore
import GoogleSignIn
import Stripe
import StripePayments

@main
struct LocalLinkApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()

    // ✅ ADD THIS
    @StateObject private var notificationRouter = NotificationRouter.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        StripeAPI.defaultPublishableKey = "pk_live_..."
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(nav)
                .environmentObject(authManager)
                .environmentObject(notificationRouter) // ✅ ADD THIS
                .onOpenURL { url in
                    print("🔥 Stripe return URL:", url)
                    NotificationCenter.default.post(name: .stripeReturn, object: nil)
                }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NotificationCenter.default.post(name: .stripeReturn, object: nil)
            }
        }
    }
}

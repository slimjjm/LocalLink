import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import StripePaymentSheet
import StripePayments

@main
struct LocalLinkApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()
    @StateObject private var notificationRouter = NotificationRouter.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        StripeAPI.defaultPublishableKey = "pk_live_51SglXVK5HcMhAFOzHoPh0x9g7I2Ed8OAQIelZ7ztksqbHLXTfycT9WCNz57II3R2tQLfsr2J9Wqw8ni2aB36oaxf001VDk8azd"
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(nav)
                .environmentObject(authManager)
                .environmentObject(notificationRouter)
                
                // 🔥 URL HANDLER (FIXED)
                .onOpenURL { url in
                    
                    print("🔥 Incoming URL:", url.absoluteString)
                    
                    // ✅ 1. Firebase Magic Link
                    if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
                        
                        print("✅ Firebase email link detected")
                        
                        authManager.completeMagicLinkSignIn(from: url) { success in
                            print("🔥 Magic link handled:", success)
                        }
                        
                        return
                    }
                    
                    // ✅ 2. STRIPE HANDLER (THIS WAS MISSING)
                    let handled = StripeAPI.handleURLCallback(with: url)
                    
                    print("💳 Stripe handled:", handled)
                }
        }
    }
}

import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import Stripe
import StripePayments

@main
struct LocalLinkApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()
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
                .environmentObject(notificationRouter)
                
                // 🔥 UNIVERSAL LINK + MAGIC LINK HANDLER
                .onOpenURL { url in
                    
                    print("🔥 Incoming URL:", url.absoluteString)
                    
                    // ✅ 1. Firebase Magic Link Handling
                    if Auth.auth().isSignIn(withEmailLink: url.absoluteString) {
                        
                        print("✅ Firebase email link detected")
                        
                        authManager.completeMagicLinkSignIn(from: url) { success in
                            print("🔥 Magic link handled:", success)
                        }
                        
                        return
                    }
                    
                    // ✅ 2. Future deep links (routing placeholder)
                    print("ℹ️ Non-auth deep link received:", url)
                    
                    // Example future routing:
                    // if url.path.contains("/booking") { ... }
                    
                    // ✅ 3. Stripe return handling
                    NotificationCenter.default.post(name: .stripeReturn, object: nil)
                }
        }
        
        // 🔥 Stripe fallback when app becomes active
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                NotificationCenter.default.post(name: .stripeReturn, object: nil)
            }
        }
    }
}

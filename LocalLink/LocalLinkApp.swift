import SwiftUI
import FirebaseCore

@main
struct LocalLinkApp: App {

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(nav)
                .environmentObject(authManager)
        }
    }
}

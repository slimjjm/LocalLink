import SwiftUI
import Firebase

@main
struct LocalLinkApp: App {

    @StateObject private var authManager = AuthManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}

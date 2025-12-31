import SwiftUI
import Firebase

@main
struct LocalLinkApp: App {

    @StateObject private var authManager: AuthManager

    init() {
        FirebaseApp.configure()
        _authManager = StateObject(wrappedValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}







import SwiftUI
import FirebaseCore

@main
struct LocalLinkApp: App {

    init() {
        FirebaseApp.configure()

        // DEV MODE ONLY
        // Always reset role on app launch
        UserDefaults.standard.removeObject(forKey: "userType")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}


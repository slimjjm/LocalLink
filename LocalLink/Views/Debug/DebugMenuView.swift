import SwiftUI

struct DebugMenuView: View {
    var body: some View {
        List {
            Section("Developer Tools") {

                Button("Reset App State") {
                    UserDefaults.standard.removeObject(forKey: "userType")
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                    UserDefaults.standard.removeObject(forKey: "hasCompletedBusinessOnboarding")
                }

                Button("Force Start Selection View") {
                    UserDefaults.standard.removeObject(forKey: "userType")
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                }
            }
        }
        .navigationTitle("Debug Menu")
    }
}

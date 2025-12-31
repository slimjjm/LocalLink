import SwiftUI

struct ContentView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        if !authManager.isReady {
            ProgressView()
        } else if authManager.userRole == nil {
            RoleSelectionView()
        } else if authManager.userRole == .business {
            BusinessRootView()
        } else {
            CustomerHomeView()
        }
    }
}

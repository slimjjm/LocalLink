import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        Group {
            if authVM.user != nil {
                // User is logged in
                HomeView()
            } else {
                // User is not logged in
                WelcomeView()
            }
        }
    }
}

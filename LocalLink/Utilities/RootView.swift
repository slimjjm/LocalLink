import SwiftUI
import FirebaseAuth

struct RootView: View {

    @AppStorage("userType") private var userType: String = ""
    @State private var isReady = false
    @State private var currentUser: User?

    var body: some View {
        NavigationStack {
            if !isReady {
                ProgressView("Starting…")
            }
            else if userType.isEmpty {
                WelcomeView()
            }
            else if userType == "customer" {
                CustomerHomeView()
            }
            else if userType == "business" {
                BusinessHomeView(
                    businessId: AppConfig.activeBusinessId
                )
            }


            else {
                WelcomeView()
            }
        }
        .task {
            await ensureSignedIn()
        }
        .onAppear {
            currentUser = Auth.auth().currentUser
        }
    }
    enum AppConfig {
        static let activeBusinessId = "demo-business-id"
    }

    private func ensureSignedIn() async {
        if Auth.auth().currentUser == nil {
            do {
                let result = try await Auth.auth().signInAnonymously()
                currentUser = result.user
            } catch {
                print("Auth error:", error.localizedDescription)
            }
        } else {
            currentUser = Auth.auth().currentUser
        }

        isReady = true
    }
}



import SwiftUI

struct RootView: View {

    @EnvironmentObject private var authManager: AuthManager

    var body: some View {
        Group {
            switch authManager.flowState {

            case .loading:
                ProgressView()

            case .unauthenticated:
                LoginView()

            case .selectingRole:
                StartSelectionView()

            case .onboardingBusiness:
                NavigationStack {
                    BusinessOnboardingView()
                }

            case .business:
                NavigationStack {
                    BusinessHomeView()
                }

            case .customer:
                NavigationStack {
                    CustomerHomeView()
                }
            }
        }
    }
}

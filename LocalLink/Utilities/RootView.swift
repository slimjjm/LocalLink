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
                BusinessOnboardingView()

            case .business:
                BusinessHomeView()

            case .customer:
                CustomerHomeView()
            }
        }
    }
}

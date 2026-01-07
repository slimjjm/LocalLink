import SwiftUI
import FirebaseAuth

struct RootView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var user: User?

    var body: some View {
        NavigationStack(path: $nav.path) {

            Group {
                if let user {
                    if user.isEmailVerified {
                        StartSelectionView()
                    } else {
                        VerifyEmailView()
                    }
                } else {
                    LoginView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {

                case .startSelection:
                    StartSelectionView()

                case .customerHome:
                    CustomerHomeView()

                case .businessGate:
                    BusinessGateView()

                case .businessOnboarding:
                    BusinessOnboardingView()

                case .businessHome(let businessId):
                    BusinessHomeView(businessId: businessId)

                case .bookingSummary(let businessId, let serviceId, let staffId, let date, let time):
                    BookingSummaryView(
                        businessId: businessId,
                        serviceId: serviceId,
                        staffId: staffId,
                        date: date,
                        time: time
                    )

                case .bookingSuccess:
                    BookingSuccessView()

                case .bookingDetail(let bookingId):
                    BookingDetailView(bookingId: bookingId)
                }
            }
        }
        .onAppear {
            listenForAuthChanges()
        }
    }

    private func listenForAuthChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.user = user

                // Optional: when user logs out, clear route stack
                if user == nil {
                    nav.reset()
                    authManager.clearRole()
                }
            }
        }
    }
}

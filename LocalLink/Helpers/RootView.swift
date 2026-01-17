import SwiftUI
import FirebaseAuth

struct RootView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var isAuthResolved = false

    var body: some View {
        NavigationStack(path: $nav.path) {

            Group {
                if !isAuthResolved {
                    ProgressView()
                } else {
                    StartSelectionView()
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .onAppear {
            listenForAuthChanges()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {

        case .startSelection:
            StartSelectionView()

        case .login:
            LoginView()

        case .register:
            RegisterView()

        case .customerHome:
            CustomerHomeView()

        case .businessGate:
            BusinessGateView()

        case .businessOnboarding:
            BusinessOnboardingView()

        case .businessHome:
            BusinessHomeView()

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

    private func listenForAuthChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                self.isAuthResolved = true

                if user == nil {
                    // If the user signed out, clear role and pop to root
                    self.nav.reset()
                    self.authManager.clearRole()
                }
            }
        }
    }
}

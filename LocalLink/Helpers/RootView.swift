import SwiftUI
import FirebaseAuth

struct RootView: View {

    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager

    @State private var showLoading = true

    var body: some View {
        Group {
            if showLoading {
                LoadingView()
            } else {
                NavigationStack(path: $nav.path) {
                    rootContent
                        .navigationDestination(for: AppRoute.self) { route in
                            destination(for: route)
                        }
                }
            }
        }
        .onAppear {
            listenForAuthChanges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSelectRole)) { _ in
            nav.reset()
        }
    }

    // MARK: - Root Router

    @ViewBuilder
    private var rootContent: some View {

        // 1️⃣ NOT LOGGED IN
        if Auth.auth().currentUser == nil {
            WelcomeView()
        }

        // 2️⃣ LOGGED IN + ROLE EXISTS
        else if let role = authManager.role {
            switch role {
            case .customer:
                CustomerHomeView()

            case .business:
                BusinessGateView()
            }
        }

        // 3️⃣ LOGGED IN BUT NO ROLE CHOSEN YET
        else {
            RoleSelectionView()
        }
    }

    // MARK: - Navigation Destinations

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {

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

        case .bookingSummary(let businessId, let serviceId, let staffId, let date, let time, let customerAddress):
            BookingSummaryView(
                businessId: businessId,
                serviceId: serviceId,
                staffId: staffId,
                date: date,
                time: time,
                customerAddress: customerAddress   // <-- important fix
            )

        case .bookingSuccess(let businessId):
            BookingSuccessView(businessId: businessId)

        case .bookingDetail(let bookingId):
            BookingDetailView(bookingId: bookingId)

        case .startSelection:
            RoleSelectionView()
        }
    }

    // MARK: - Auth Listener

    private func listenForAuthChanges() {
        Auth.auth().addStateDidChangeListener { _, user in

            DispatchQueue.main.async {
                self.showLoading = false
            }

            if user == nil {
                nav.reset()
                authManager.clearRole()
            }
        }
    }
}

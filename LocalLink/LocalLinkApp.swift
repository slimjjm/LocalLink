import SwiftUI
import Firebase

@main
struct LocalLinkApp: App {

    @StateObject private var nav = NavigationState()
    @StateObject private var authManager = AuthManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $nav.path) {

                // Root view (role selection)
                StartSelectionView()
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {

                        // MARK: - Customer
                        case .customerHome:
                            CustomerHomeView()

                        // MARK: - Business
                        case .businessHome:
                            BusinessHomeView()

                        case .businessOnboarding:
                            BusinessOnboardingView()

                        // MARK: - Booking flow
                        case let .bookingSummary(
                            businessId,
                            serviceId,
                            staffId,
                            date,
                            time
                        ):
                            BookingSummaryView(
                                businessId: businessId,
                                serviceId: serviceId,
                                staffId: staffId,
                                date: date,
                                time: time
                            )

                        case .bookingSuccess:
                            BookingSuccessView()

                        // ✅ ADD THIS
                        case let .bookingDetail(bookingId):
                            BookingDetailView(bookingId: bookingId)
                        }
                    }
            }
            .environmentObject(nav)
            .environmentObject(authManager)
        }
    }
}


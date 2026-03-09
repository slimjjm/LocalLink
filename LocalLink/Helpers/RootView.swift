import SwiftUI

struct RootView: View {
    
    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        
        NavigationStack(path: $nav.path) {
            
            rootContent
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didSelectRole)) { _ in
            nav.reset()
        }
    }
    
    // MARK: - Root Router
    
    @ViewBuilder
    private var rootContent: some View {
        
        if !authManager.isAuthenticated {
            WelcomeView()
        } else if authManager.isRoleLoading {
            LoadingView()
        } else if let role = authManager.role {
            switch role {
            case .customer:
                CustomerHomeView()
            case .business:
                BusinessGateView()
            }
        } else {
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
            
        case .bookingSummary(
            let businessId,
            let serviceId,
            let staffId,
            let slotId,
            let date,
            let time,
            let customerAddress
        ):
            
            BookingSummaryView(
                businessId: businessId,
                serviceId: serviceId,
                staffId: staffId,
                slotId: slotId,
                date: date,
                time: time,
                customerAddress: customerAddress
            )
            
        case .bookingSuccess(let businessId, let bookingId):
            
            BookingSuccessView(
                businessId: businessId,
                bookingId: bookingId
            )
            
        case .bookingDetail(let bookingId, let role):
            
            BookingDetailView(
                bookingId: bookingId,
                currentUserRole: role
            )
            
        case .editStaffSkills(let businessId, let staffId, _):
            
            EditStaffSkillsView(
                businessId: businessId,
                staffId: staffId
            )
            
        case .editWeeklyAvailability(let businessId, let staffId, _):
            
            WeeklyAvailabilityEditView(
                businessId: businessId,
                staffId: staffId
            )
        }
    }
}

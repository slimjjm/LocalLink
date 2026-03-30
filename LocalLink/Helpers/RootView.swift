import SwiftUI

struct RootView: View {
    
    @EnvironmentObject private var nav: NavigationState
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var notificationRouter: NotificationRouter
    
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
        .onChange(of: notificationRouter.bookingIdToOpen) { bookingId in
            
            guard let bookingId else { return }
            
            // ✅ Clean navigation (correct label)
            nav.path.append(.bookingChat(bookingId: bookingId))
            
            // ✅ Reset after navigation
            notificationRouter.bookingIdToOpen = nil
        }
    }
    
    // MARK: - Root Router
    
    @ViewBuilder
    private var rootContent: some View {
        
        if !authManager.isAuthenticated && authManager.role == nil {
            
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
            AuthEntryView()
            
        case .register:
            AuthEntryView()
            
            // MARK: - Auth
            
        case .authEntry:
            AuthEntryView()
            
        case .roleSelection:
            RoleSelectionView()
            
            // MARK: - Customer
            
        case .customerHome:
            CustomerHomeView()
            
            // MARK: - Business
            
        case .businessGate:
            BusinessGateView()
            
        case .businessOnboarding:
            BusinessOnboardingView()
            
        case .businessHome:
            BusinessHomeView()
            
            // MARK: - Booking Flow
            
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
            
            // MARK: - Booking Chat
            
        case .bookingChat(let bookingId):
            
            // ✅ SAFE DEFAULT VERSION (no crashes, works now)
            BookingChatView(
                bookingId: bookingId,
                businessId: "",
                customerId: "",
                currentUserRole: authManager.role == .business ? "business" : "customer"
            )
            
            // MARK: - Staff
            
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

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
        
        // ✅ Return to pending route after login
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            
            guard isAuthenticated else { return }
            
            if let pending = nav.pendingRoute {
                nav.reset()
                nav.path.append(pending)
                nav.pendingRoute = nil
            }
        }
        
        // ✅ Reset navigation when role changes
        .onReceive(NotificationCenter.default.publisher(for: .didSelectRole)) { _ in
            nav.reset()
        }
        
        // 🔔 Deep link into booking chat
        .onChange(of: notificationRouter.bookingIdToOpen) { bookingId in
            
            guard let bookingId else { return }
            
            nav.path.append(AppRoute.bookingChat(bookingId: bookingId))
            notificationRouter.bookingIdToOpen = nil
        }
    }
}

// MARK: - ROOT ROUTER

private extension RootView {
    
    @ViewBuilder
    var rootContent: some View {
        
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
}

// MARK: - DESTINATIONS

private extension RootView {
    
    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        
        switch route {
            
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
            
            
        // MARK: - Chat
            
        case .bookingChat(let bookingId):
            BookingChatView(
                bookingId: bookingId,
                businessId: "",        // ✅ leave empty (BookingChatView loads it)
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
        default:
            Text("Coming soon")
        }
    }
}

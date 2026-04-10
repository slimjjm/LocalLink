import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import FirebaseFirestore

struct BusinessHomeView: View {
    
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject private var nav: NavigationState
    
    @StateObject private var resolver = BusinessResolverViewModel()
    @StateObject private var bookingsVM = BusinessBookingsViewModel()
    @StateObject private var unreadVM = ChatUnreadViewModel()
    
    @State private var restrictionMode: Bool = false
    @State private var stripeStatus: String = "free"
    @State private var pastDueSince: Timestamp?
    
    @State private var stripeConnected: Bool = false
    @State private var maxStaff: Int = 1
    @State private var entitlementsListener: ListenerRegistration?
    
    private let functions = Functions.functions(region: "us-central1")
    
    var body: some View {
        
        Group {
            
            if resolver.isLoading {
                ProgressView("Loading business…")
                
            } else if !resolver.errorMessage.isEmpty {
                errorState
                
            } else if let businessId = resolver.selectedBusinessId {
                
                content(businessId: businessId)
                    .onAppear {
                        guard entitlementsListener == nil else { return }
                        
                        loadBusinessData(businessId: businessId)
                        startStripeListener(businessId: businessId)
                        startEntitlementsListener(businessId: businessId)
                        
                        unreadVM.startListening(role: "business", businessId: businessId)
                    }
                    .onDisappear {
                        entitlementsListener?.remove()
                        unreadVM.stopListening()
                    }
            }
        }
        .navigationBarBackButtonHidden(true) // 🔥 THIS FIXES YOUR ISSUE
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Change role") {
                    authManager.clearRole()
                    nav.reset()
                }
            }
        }
        .onAppear {
            if resolver.businesses.isEmpty {
                resolver.load()
            }
        }
    }
    
    // MARK: CONTENT
    
    private func content(businessId: String) -> some View {
        
        ScrollView {
            
            VStack(spacing: 28) {
                
                headerSection
                
                stripeConnectTile
                
                BusinessDayScrollerView(businessId: businessId, viewModel: bookingsVM)
                BusinessEarningsView(businessId: businessId, viewModel: bookingsVM)
                BusinessCapacityTileView(viewModel: bookingsVM)
                
                quickActions(businessId: businessId)
                
                managementSection(businessId: businessId)
                
                switchRoleButton
            }
            .padding()
        }
        .background(AppColors.background)
    }
    
    // MARK: HEADER
    
    private var businessName: String {
        resolver.selectedBusiness?.businessName ?? "Your Business"
    }
    
    private var headerSection: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    
                    Text("Welcome back")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(businessName)
                        .font(.system(size: 28, weight: .bold))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "building.2.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1)
        }
    }
    
    // MARK: QUICK ACTIONS
    
    private func quickActions(businessId: String) -> some View {
        
        VStack(spacing: 12) {
            
            sectionHeader("Quick actions")
            
            NavigationLink {
                BusinessBookingsView(businessId: businessId)
            } label: {
                actionRow(
                    title: "Bookings",
                    subtitle: "View upcoming appointments",
                    icon: "calendar"
                )
            }
            
            NavigationLink {
                BusinessInboxView(businessId: businessId)
            } label: {
                actionRow(
                    title: "Messages",
                    subtitle: "Customer enquiries",
                    icon: "bubble.left.and.bubble.right.fill"
                )
            }
        }
    }
    
    // MARK: MANAGEMENT
    
    private func managementSection(businessId: String) -> some View {
        
        VStack(spacing: 12) {
            
            sectionHeader("Manage")
            
            NavigationLink {
                BusinessServiceListView(businessId: businessId)
            } label: {
                actionRow(
                    title: "Services",
                    subtitle: "Pricing & durations",
                    icon: "scissors"
                )
            }
            
            NavigationLink {
                BusinessStaffListView(businessId: businessId)
            } label: {
                actionRow(
                    title: "Team",
                    subtitle: "Staff & availability",
                    icon: "person.2.fill"
                )
            }
            
            NavigationLink {
                BusinessBookingCalendarView(
                    businessId: businessId,
                    staff: bookingsVM.staff
                )
            } label: {
                actionRow(
                    title: "Calendar",
                    subtitle: "Manage schedule",
                    icon: "calendar.badge.clock"
                )
            }
            
            NavigationLink {
                BusinessSubscriptionResolverView()
            } label: {
                actionRow(
                    title: "Subscription",
                    subtitle: "Plan & billing",
                    icon: "creditcard.fill"
                )
            }
            
            NavigationLink {
                BusinessProfileContainerView(businessId: businessId)
            } label: {
                actionRow(
                    title: "Business profile",
                    subtitle: "Public page",
                    icon: "person.crop.square"
                )
            }
            
            NavigationLink {
                SettingsView()
            } label: {
                actionRow(
                    title: "Settings",
                    subtitle: "App preferences",
                    icon: "gearshape"
                )
            }
        }
    }
    
    // MARK: ACTION ROW
    
    private func actionRow(title: String, subtitle: String, icon: String) -> some View {
        
        HStack(spacing: 14) {
            
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding()
        .background(premiumCard)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: STRIPE
    
    private var stripeConnectTile: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Image(systemName: "creditcard.fill")
                    .foregroundColor(AppColors.primary)
                
                Text("Payments")
                    .font(.headline)
            }
            
            if stripeConnected {
                Text("Payments active")
            } else {
                Button("Finish setup") {
                    print("Stripe onboarding tapped")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(premiumCard)
    }
    
    // MARK: SWITCH ROLE
    
    private var switchRoleButton: some View {
        
        Button {
            UserDefaults.standard.set("customer", forKey: "userRole")
            nav.reset()
            nav.path.append(.customerHome)
        } label: {
            
            HStack {
                Image(systemName: "person.fill")
                
                VStack(alignment: .leading) {
                    Text("Switch to customer")
                    Text("Browse services")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(premiumCard)
        }
    }
    
    // MARK: CARD
    
    private var premiumCard: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
    
    // MARK: FIREBASE
    
    private func startStripeListener(businessId: String) {
        Firestore.firestore()
            .collection("businesses")
            .document(businessId)
            .addSnapshotListener { snapshot, _ in
                stripeConnected = snapshot?.data()?["stripeConnected"] as? Bool ?? false
            }
    }
    
    private func startEntitlementsListener(businessId: String) {
        
        entitlementsListener?.remove()
        
        entitlementsListener = Firestore.firestore()
            .collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .addSnapshotListener { snapshot, _ in
                
                guard let data = snapshot?.data() else { return }
                
                let free = data["freeStaffSlots"] as? Int ?? 1
                let extra = data["extraStaffSlots"] as? Int ?? 0
                
                maxStaff = free + extra
                restrictionMode = data["restrictionMode"] as? Bool ?? false
                stripeStatus = data["stripeStatus"] as? String ?? "free"
                pastDueSince = data["pastDueSince"] as? Timestamp
            }
    }
    
    private func loadBusinessData(businessId: String) {
        bookingsVM.loadBookings(for: businessId)
        bookingsVM.loadStaff(for: businessId)
    }
    
    private var errorState: some View {
        VStack {
            Text("Error")
            Text(resolver.errorMessage)
        }
    }
}

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
    
    // MARK: Billing State
    
    @State private var restrictionMode: Bool = false
    @State private var stripeStatus: String = "free"
    @State private var pastDueSince: Timestamp?
    
    @State private var stripeConnected: Bool = false
    
    @State private var showRecoverySuccess: Bool = false
    @State private var previousRestrictionMode: Bool = false
    @State private var previousStripeStatus: String = "free"
    
    // Countdown
    @State private var graceTimeRemaining: TimeInterval?
    private let graceDuration: TimeInterval = 7 * 24 * 60 * 60
    
    @State private var entitlementsListener: ListenerRegistration?
    
    private let functions = Functions.functions(region: "us-central1")
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // MARK: Body
    
    var body: some View {
        
        Group {
            
            if resolver.isLoading {
                
                ProgressView("Loading business…")
                
            } else if !resolver.errorMessage.isEmpty {
                
                errorState
                
            } else if let businessId = resolver.selectedBusinessId {
                
                content(businessId: businessId)
                    .onAppear {
                        
                        loadBusinessData(businessId: businessId)
                        startStripeListener(businessId: businessId)
                        
                        startEntitlementsListener(businessId: businessId)
                        
                        unreadVM.startListening(
                            role: "business",
                            businessId: businessId
                        )
                    }
                    .onDisappear {
                        
                        entitlementsListener?.remove()
                        entitlementsListener = nil
                        
                        unreadVM.stopListening()
                    }
                
            } else {
                
                ProgressView("Loading business…")
            }
        }
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        
        // ✅ TIMER
        .onReceive(timer) { _ in
            updateCountdown()
        }
        
        // ✅ STRIPE RETURN (THIS IS THE FIX)
        .onReceive(NotificationCenter.default.publisher(for: .stripeReturn)) { _ in
            print("🔄 Stripe return detected")
            
            if let businessId = resolver.selectedBusinessId {
                loadBusinessData(businessId: businessId)
            }
        }
        
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
    // MARK: Stripe Connection
    
    private func startStripeListener(businessId: String) {
        
        Firestore.firestore()
            .collection("businesses")
            .document(businessId)
            .addSnapshotListener { snapshot, error in
                
                guard let data = snapshot?.data() else { return }
                
                DispatchQueue.main.async {
                    
                    stripeConnected = data["stripeConnected"] as? Bool ?? false
                }
            }
    }
    
    // MARK: Entitlements Listener
    
    private func startEntitlementsListener(businessId: String) {
        
        let db = Firestore.firestore()
        
        entitlementsListener?.remove()
        entitlementsListener = nil
        
        entitlementsListener = db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .addSnapshotListener { snapshot, error in
                
                guard error == nil else { return }
                guard let data = snapshot?.data() else { return }
                
                let newRestriction = data["restrictionMode"] as? Bool ?? false
                let newStripeStatus = data["stripeStatus"] as? String ?? "free"
                let newPastDue = data["pastDueSince"] as? Timestamp
                
                DispatchQueue.main.async {
                    
                    if previousRestrictionMode == true && newRestriction == false {
                        triggerRecoverySuccess()
                    }
                    
                    if previousStripeStatus == "past_due" && newStripeStatus == "active" {
                        triggerRecoverySuccess()
                    }
                    
                    restrictionMode = newRestriction
                    stripeStatus = newStripeStatus
                    pastDueSince = newPastDue
                    
                    calculateCountdown()
                    
                    previousRestrictionMode = newRestriction
                    previousStripeStatus = newStripeStatus
                }
            }
    }
    
    private func triggerRecoverySuccess() {
        
        showRecoverySuccess = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            
            withAnimation(.easeInOut) {
                showRecoverySuccess = false
            }
        }
    }
    
    // MARK: Countdown
    
    private func calculateCountdown() {
        
        guard stripeStatus == "past_due",
              restrictionMode == false,
              let pastDueSince else {
            
            graceTimeRemaining = nil
            return
        }
        
        let elapsed = Date().timeIntervalSince(pastDueSince.dateValue())
        
        graceTimeRemaining = max(0, graceDuration - elapsed)
    }
    
    private func updateCountdown() {
        
        guard stripeStatus == "past_due",
              restrictionMode == false,
              let remaining = graceTimeRemaining,
              remaining > 0 else { return }
        
        graceTimeRemaining = remaining - 1
    }
    
    private func formattedCountdown() -> String {
        
        guard let remaining = graceTimeRemaining else {
            return "Please update your payment method to avoid restriction."
        }
        
        let total = max(0, Int(remaining))
        
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        return "Update payment to avoid restriction • \(days)d \(hours)h \(minutes)m \(seconds)s remaining"
    }
    
    // MARK: Load Data
    
    private func loadBusinessData(businessId: String) {
        
        bookingsVM.loadBookings(for: businessId)
        bookingsVM.loadStaff(for: businessId)
    }
    
    // MARK: Error
    
    private var errorState: some View {
        
        VStack(spacing: 14) {
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(AppColors.error)
            
            Text("Business not ready")
                .font(.headline)
            
            Text(resolver.errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                resolver.load()
            }
        }
        .padding()
    }
    
    // MARK: Main Content
    
    private func content(businessId: String) -> some View {
        
        ScrollView {
            
            VStack(spacing: 28) {
                
                headerSection
                
                stripeConnectTile
                
                if unreadVM.totalUnread > 0 {
                    
                    NavigationLink {
                        
                        BusinessBookingsView(businessId: businessId)
                        
                    } label: {
                        
                        HStack {
                            
                            Image(systemName: "message.fill")
                            
                            Text("You have \(unreadVM.totalUnread) unread message\(unreadVM.totalUnread > 1 ? "s" : "")")
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(AppColors.primary.opacity(0.15))
                        .cornerRadius(12)
                    }
                }
                
                BusinessDayScrollerView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )
                
                BusinessEarningsView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )
                
                BusinessCapacityTileView(viewModel: bookingsVM)
                
                staffUsageTile(businessId: businessId)
                
                menuGrid(businessId: businessId)
                
                switchRoleButton
            }
            .padding()
        }
        .background(AppColors.background)
    }
    
    // MARK: Stripe Tile
    
    private var stripeConnectTile: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            Text("Payments")
                .font(.headline)
            
            if stripeConnected {
                
                Label("Stripe connected", systemImage: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                
            } else {
                
                VStack(alignment: .leading, spacing: 10) {
                    
                    Label(
                        "Connect Stripe to accept bookings",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundColor(AppColors.error)
                    
                    NavigationLink {
                        
                        StripeConnectView()
                        
                    } label: {
                        
                        Text("Connect Stripe")
                            .primaryButton()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: Header
    
    private var headerSection: some View {
        
        VStack(alignment: .leading) {
            
            Text("Business Dashboard")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: Staff
    
    private func staffUsageTile(businessId: String) -> some View {
        
        NavigationLink {
            
            BusinessStaffListView(businessId: businessId)
            
        } label: {
            
            HStack {
                
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading) {
                    
                    Text("Staff")
                        .font(.caption)
                    
                    Text("Manage staff & availability")
                        .font(.headline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: Menu Grid
    
    private func menuGrid(businessId: String) -> some View {
        
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 20
        ) {
            // 🔥 INBOX ENTRY (REPLACES OLD UNREAD SECTION)

            NavigationLink {
                
                BusinessInboxView(businessId: businessId)
                
            } label: {
                
                HStack {
                    
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    
                    VStack(alignment: .leading, spacing: 2) {
                        
                        Text("Inbox")
                            .font(.headline)
                        
                        Text("View enquiries & messages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if unreadVM.totalUnread > 0 {
                        Text("\(unreadVM.totalUnread)")
                            .font(.caption.bold())
                            .padding(8)
                            .background(AppColors.error)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(AppColors.primary.opacity(0.12))
                .cornerRadius(14)
            }
            // SERVICES
            
            NavigationLink {
                BusinessServiceListView(businessId: businessId)
            } label: {
                menuTile(title: "Services", icon: "scissors")
            }
            
            // BOOKINGS
            
            NavigationLink {
                BusinessBookingsView(businessId: businessId)
            } label: {
                menuTile(title: "Bookings", icon: "book.closed")
            }
            
            // ADD BOOKING
            
            NavigationLink {
                
                if !bookingsVM.staff.isEmpty {
                    
                    StaffSelectionView(
                        businessId: businessId,
                        staff: bookingsVM.staff,
                        mode: .manualBooking
                    )
                    
                } else {
                    missingStaffView
                }
                
            } label: {
                menuTile(title: "Add booking", icon: "calendar.badge.plus")
            }
            
            // BLOCK TIME
            
            NavigationLink {
                
                if !bookingsVM.staff.isEmpty {
                    
                    StaffSelectionView(
                        businessId: businessId,
                        staff: bookingsVM.staff,
                        mode: .blockTime
                    )
                    
                } else {
                    missingStaffView
                }
                
            } label: {
                menuTile(title: "Block time", icon: "calendar.badge.minus")
            }
            
            // CALENDAR
            
            NavigationLink {
                
                if !bookingsVM.staff.isEmpty {
                    
                    BusinessBookingCalendarView(
                        businessId: businessId,
                        staff: bookingsVM.staff
                    )
                    
                } else {
                    missingStaffView
                }
                
            } label: {
                menuTile(title: "Calendar", icon: "calendar.circle")
            }
            
            
            // PROFILE
            
            NavigationLink {
                BusinessProfileContainerView(businessId: businessId)
            } label: {
                menuTile(title: "Profile", icon: "building.2")
            }
            
            // BILLING
            
            Button {
                openBillingPortal()
            } label: {
                menuTile(title: "Billing", icon: "creditcard")
            }
            
            // SETTINGS
            
            NavigationLink {
                SettingsView()
            } label: {
                menuTile(title: "Settings", icon: "gearshape")
            }
        }
    }
    private var missingStaffView: some View {
        
        VStack {
            Text("Please add a staff member first")
                .foregroundColor(.secondary)
                .padding()
        }
    }
    // MARK: Billing Portal
    
    private func openBillingPortal() {
        
        functions.httpsCallable("createStripePortalLink").call { result, error in
            
            if let error {
                print("Portal error:", error.localizedDescription)
                return
            }
            
            if let dict = result?.data as? [String: Any],
               let urlString = dict["url"] as? String,
               let url = URL(string: urlString) {
                
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: Switch Role
    
    private var switchRoleButton: some View {
        
        Button {
            
            nav.reset()
            
        } label: {
            
            HStack {
                
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading) {
                    
                    Text("Back to welcome")
                        .font(.headline)
                    
                    Text("Switch between customer and business mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: Tile
    
    private func menuTile(title: String, icon: String) -> some View {
        
        HStack {
            
            VStack(alignment: .leading, spacing: 8) {
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
                
                Text(title)
                    .font(.headline)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

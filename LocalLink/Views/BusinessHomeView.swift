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
    
    // MARK: - Billing State
    
    @State private var restrictionMode: Bool = false
    @State private var stripeStatus: String = "free"
    @State private var pastDueSince: Timestamp?
    
    @State private var showRecoverySuccess: Bool = false
    @State private var previousRestrictionMode: Bool = false
    @State private var previousStripeStatus: String = "free"
    
    // Countdown (7 days)
    @State private var graceTimeRemaining: TimeInterval?
    private let graceDuration: TimeInterval = 7 * 24 * 60 * 60
    
    // IMPORTANT: must be @State so we can mutate/remove it inside a View struct
    @State private var entitlementsListener: ListenerRegistration?
    
    private let functions = Functions.functions(region: "us-central1")
    
    // Live timer (ticks every second)
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // MARK: - Body
    
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
                        startEntitlementsListener(businessId: businessId)
                        unreadVM.startListening(role: "business")
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
        .navigationBarBackButtonHidden(true) // ✅ root screen: prevent return to onboarding
        .onReceive(timer) { _ in
            updateCountdown()
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
    
    // MARK: - Entitlements Listener
    
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
                    
                    // Detect recovery
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut) {
                showRecoverySuccess = false
            }
        }
    }
    
    // MARK: - Countdown Logic
    
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
    
    // MARK: - Load
    
    private func loadBusinessData(businessId: String) {
        bookingsVM.loadBookings(for: businessId)
        bookingsVM.loadStaff(for: businessId)
    }
    
    // MARK: - Error State
    
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
                .padding(.horizontal)
            
            Button("Retry") {
                resolver.load()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    // MARK: - Main Content

    private func content(businessId: String) -> some View {

        ScrollView {

            VStack(spacing: 28) {

                headerSection

                // 🔔 UNREAD CHAT BANNER

                if unreadVM.totalUnread > 0 {

                    NavigationLink {

                        BusinessBookingsView(businessId: businessId)

                    } label: {

                        HStack(spacing: 10) {

                            Image(systemName: "message.fill")

                            Text("You have \(unreadVM.totalUnread) unread message\(unreadVM.totalUnread > 1 ? "s" : "")")
                                .lineLimit(2)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                        }
                        .font(.footnote.weight(.semibold))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AppColors.primary.opacity(0.15))
                        .foregroundColor(AppColors.primary)
                        .cornerRadius(12)

                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // 🟢 RECOVERY

                if showRecoverySuccess {

                    billingBanner(
                        color: .green,
                        title: "Payment Updated",
                        message: "Billing issue resolved. Full access restored."
                    )
                    .transition(.opacity)

                }

                // 🔴 HARD RESTRICTION

                if restrictionMode {

                    billingBanner(
                        color: .red,
                        title: "Account Restricted",
                        message: "Your account is temporarily restricted due to unpaid billing. Update payment to restore access."
                    )

                }

                // 🟠 GRACE PERIOD

                else if stripeStatus == "past_due" {

                    billingBanner(
                        color: .orange,
                        title: "Payment Issue Detected",
                        message: formattedCountdown()
                    )
                }

                // TODAY (moved to top)

                BusinessDayScrollerView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )

                // MONTH PERFORMANCE

                BusinessEarningsView(
                    businessId: businessId,
                    viewModel: bookingsVM
                )
                .padding()
                .background(Color.white)
                .cornerRadius(16)

                // CALENDAR UTILISATION

                BusinessCapacityTileView(viewModel: bookingsVM)

                // STAFF

                staffUsageTile(businessId: businessId)

                // MENU

                menuGrid(businessId: businessId)

                // ROLE SWITCH

                switchRoleButton
            }
            .padding()
        }
        .background(AppColors.background)
        .animation(.easeInOut(duration: 0.2), value: unreadVM.totalUnread)
    }
    // MARK: - Billing Banner
    
    private func billingBanner(color: Color, title: String, message: String) -> some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(message)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(.white.opacity(0.95))
            
            Button {
                openBillingPortal()
            } label: {
                Text("Fix Billing")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(color.opacity(0.9))
        .cornerRadius(16)
        .animation(.easeInOut(duration: 0.25), value: graceTimeRemaining)
    }
    
    // MARK: - Billing
    
    private func openBillingPortal() {
        
        functions.httpsCallable("createStripePortalLink").call { result, error in
            
            if let error {
                print("❌ Portal error:", error.localizedDescription)
                return
            }
            
            if let dict = result?.data as? [String: Any],
               let urlString = dict["url"] as? String,
               let url = URL(string: urlString) {
                
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
                return
            }
            
            print("❌ Portal: invalid response shape. Expected { url: \"...\" }")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Business Dashboard")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Staff Tile
    
    private func staffUsageTile(businessId: String) -> some View {
        
        NavigationLink {
            BusinessStaffListView(businessId: businessId)
        } label: {
            
            HStack(spacing: 16) {
                
                Image(systemName: "person.2.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    
                    Text("Staff")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Manage staff & availability")
                        .font(.headline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }
    
    // MARK: - Menu Grid

    private func menuGrid(businessId: String) -> some View {

        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 20
        ) {

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

            // MANUAL BOOKING

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
                BusinessProfileView(businessId: businessId)
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
    
    // MARK: - Missing Staff View
    
    private var missingStaffView: some View {
        
        VStack {
            Text("Please add a staff member first")
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    // MARK: - Switch Role
    
    private var switchRoleButton: some View {
        
        Button {
            nav.reset()
        } label: {
            
            HStack {
                
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
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
    
    // MARK: - Tile
    
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
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

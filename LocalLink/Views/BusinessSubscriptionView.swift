import SwiftUI
import FirebaseFirestore
import StoreKit

struct BusinessSubscriptionView: View {
    
    let businessId: String
    
    // MARK: - State
    
    @State private var freeSeats = 1
    @State private var extraSeats = 0
    @State private var staffCount = 0
    @State private var restrictionMode = false
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    @StateObject private var unlockVM = StaffUnlockViewModel()
    @State private var entitlementListener: ListenerRegistration?
    
    private let db = Firestore.firestore()
    
    // MARK: - Derived
    
    private var totalSeats: Int { freeSeats + extraSeats }
    private var activeSeats: Int { min(staffCount, totalSeats) }
    private var inactiveSeats: Int { max(0, staffCount - totalSeats) }
    
    private var usageProgress: Double {
        guard totalSeats > 0 else { return 0 }
        return min(Double(staffCount) / Double(totalSeats), 1.0)
    }
    
    private var isPaid: Bool { extraSeats > 0 }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                if isLoading {
                    loadingCard
                } else {
                    heroCard
                    usageCard
                    
                    if restrictionMode {
                        restrictionBanner
                    }
                    
                    if unlockVM.isInGracePeriod {
                        graceBanner
                    }
                    
                    purchaseCard
                    
                    if let errorMessage {
                        infoMessage(errorMessage, color: AppColors.error)
                    }
                }
            }
            .padding(16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Subscription")
        .onAppear {
            startListening()
            Task {
                await unlockVM.configure(businessId: businessId)
            }
        }
        .onDisappear {
            entitlementListener?.remove()
        }
    }
    
    // MARK: - Cards
    
    private var loadingCard: some View {
        ProgressView("Loading subscription...")
            .frame(maxWidth: .infinity)
            .padding()
            .background(cardBackground)
    }
    
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Staff Seats")
                .font(.title2.bold())
            
            Text("Scale your business by unlocking additional staff.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                metric("Included", freeSeats)
                metric("Paid", extraSeats)
                metric("Total", totalSeats)
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text("Usage")
                Spacer()
                Text("\(staffCount)/\(totalSeats)")
            }
            
            ProgressView(value: usageProgress)
                .tint(usageProgress >= 1 ? AppColors.error : AppColors.primary)
            
            Text("\(activeSeats) active • \(inactiveSeats) over limit")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(cardBackground)
    }
    
    private var restrictionBanner: some View {
        Text("Billing issue — account restricted")
            .foregroundColor(AppColors.error)
            .padding()
    }
    
    private var graceBanner: some View {
        Text("Payment issue — subscription in grace period")
            .font(.footnote.bold())
            .foregroundColor(AppColors.error)
            .padding(.horizontal)
    }
    
    // MARK: - PURCHASE CARD (FIXED FOR APPLE)
    
    private var purchaseCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // MARK: - Header
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Upgrade")
                    .font(.headline)
                
                Text("Unlock additional staff slots")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // MARK: - Plans
            
            ForEach(StaffUnlockViewModel.SeatPlan.allCases) { plan in
                
                Button {
                    Task {
                        let result = await unlockVM.purchase(plan: plan)
                        if result == .failed {
                            errorMessage = unlockVM.errorMessage
                        }
                    }
                } label: {
                    HStack {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            
                            Text(plan.title)
                                .font(.body.weight(.semibold))
                            
                            Text("Monthly subscription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if let product = unlockVM.product(for: plan) {
                            Text(product.displayPrice)
                                .font(.body.weight(.bold))
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 6)
                    )
                }
                .disabled(unlockVM.isWorking || unlockVM.isActive(plan: plan))
                .opacity(unlockVM.isActive(plan: plan) ? 0.5 : 1)
            }
            
            Divider()
            
            // MARK: - LEGAL (APPLE REQUIRED)
            
            VStack(alignment: .leading, spacing: 10) {
                
                Text("Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your Apple account settings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                Text("Payment will be charged to your Apple ID account at confirmation of purchase.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                HStack {
                    Link("Terms of Use", destination: URL(string: "https://locallinkapp.co.uk/terms")!)
                    Spacer()
                    Link("Privacy Policy", destination: URL(string: "https://locallinkapp.co.uk/privacy")!)
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.primary)
            }
            
            // MARK: - ACTIONS
            
            VStack(alignment: .leading, spacing: 12) {
                
                Button("Restore Purchases") {
                    Task { _ = await unlockVM.restorePurchases() }
                }
                .foregroundColor(AppColors.primary)
                
                Button("Manage Subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(cardBackground)
    }
    
    // MARK: - Components
    
    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            Text("\(value)").bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func infoMessage(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundColor(color)
            .padding()
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .shadow(radius: 5)
    }
    
    // MARK: - Firestore
    
    private func startListening() {
        entitlementListener?.remove()
        
        entitlementListener = db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .addSnapshotListener { snap, _ in
                
                guard let data = snap?.data() else { return }
                
                freeSeats = data["freeStaffSlots"] as? Int ?? 1
                extraSeats = data["extraStaffSlots"] as? Int ?? 0
                restrictionMode = data["restrictionMode"] as? Bool ?? false
                
                refreshStaffCount()
            }
    }
    
    private func refreshStaffCount() {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { snap, _ in
                staffCount = snap?.documents.count ?? 0
                isLoading = false
            }
    }
}

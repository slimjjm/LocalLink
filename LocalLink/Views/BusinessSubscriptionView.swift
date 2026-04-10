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
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                if isLoading {
                    ProgressView("Loading subscription...")
                } else {
                    
                    // MARK: - HERO
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Staff Capacity")
                            .font(.title2.bold())
                        
                        Text("Take more bookings with more staff.")
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
                    
                    // MARK: - USAGE
                    
                    VStack(alignment: .leading, spacing: 12) {
                        
                        HStack {
                            Text("Usage")
                            Spacer()
                            Text("\(staffCount)/\(totalSeats)")
                        }
                        
                        ProgressView(value: usageProgress)
                            .tint(usageProgress >= 1 ? .red : .orange)
                        
                        Text("\(activeSeats) active • \(inactiveSeats) over limit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(cardBackground)
                    
                    // MARK: - PURCHASE
                    
                    VStack(alignment: .leading, spacing: 16) {
                        
                        Text("Upgrade")
                            .font(.headline)
                        
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
                                        
                                        Text(plan.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let badge = plan.badge {
                                            Text(badge)
                                                .font(.caption2.bold())
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if let product = unlockVM.product(for: plan) {
                                        Text(product.displayPrice)
                                            .font(.body.bold())
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
                        
                        Button("Restore Purchases") {
                            Task { _ = await unlockVM.restorePurchases() }
                        }
                        
                        Button("Manage Subscription") {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(cardBackground)
                }
            }
            .padding()
        }
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
    
    // MARK: - Components
    
    private func metric(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption)
            Text("\(value)").bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

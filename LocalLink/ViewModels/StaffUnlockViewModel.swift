import Foundation
import StoreKit
import FirebaseFunctions

@MainActor
final class StaffUnlockViewModel: ObservableObject {
    
    // MARK: - Checkout State
    
    enum CheckoutState {
        case completed
        case canceled
        case failed
    }
    
    // MARK: - Plans (UPDATED 🔥)
    
    enum SeatPlan: String, CaseIterable, Identifiable {
        case one = "locallink.staff.1"
        case three = "locallink.staff.3"
        case five = "locallink.staff.5"
        
        var id: String { rawValue }
        
        var extraSeats: Int {
            switch self {
            case .one: return 1
            case .three: return 3
            case .five: return 5
            }
        }
        
        // 🔥 NEW — CLEAN CAPACITY LABEL
        var title: String {
            "+\(extraSeats) staff"
        }
        
        // 🔥 NEW — SUPPORTING TEXT
        var subtitle: String {
            switch self {
            case .one:
                return "Perfect for growing solo"
            case .three:
                return "Take on more bookings"
            case .five:
                return "Maximise daily capacity"
            }
        }
        
        // 🔥 KEEP BADGES (GOOD FOR CONVERSION)
        var badge: String? {
            switch self {
            case .one: return nil
            case .three: return "Grow your capacity"
            case .five: return "Best value"
            }
        }
    }
    
    // MARK: - Published
    
    @Published var isWorking = false
    @Published var isLoadingProducts = false
    @Published var errorMessage: String?
    
    @Published var products: [Product] = []
    
    @Published var activeProductID: String?
    @Published var activeExtraSeats: Int = 0
    
    @Published var isInGracePeriod = false
    @Published var renewalDate: Date?
    
    // MARK: - Private
    
    private let functions = Functions.functions(region: "us-central1")
    private let productIDs = Set(SeatPlan.allCases.map(\.rawValue))
    
    private var currentBusinessId: String?
    private var updatesTask: Task<Void, Never>?
    
    private var currentPlan: SeatPlan? {
        guard let activeProductID else { return nil }
        return SeatPlan(rawValue: activeProductID)
    }
    
    // MARK: - Setup
    
    func configure(businessId: String) async {
        currentBusinessId = businessId
        errorMessage = nil
        
        await loadProducts()
        await refreshEntitlementsFromApple()
        startTransactionListenerIfNeeded()
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - Products
    
    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil
        
        defer { isLoadingProducts = false }
        
        do {
            let loaded = try await Product.products(for: productIDs)
            
            products = loaded.sorted {
                (SeatPlan(rawValue: $0.id)?.extraSeats ?? 0) <
                (SeatPlan(rawValue: $1.id)?.extraSeats ?? 0)
            }
            
        } catch {
            errorMessage = "Unable to load App Store products: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Purchase
    
    func purchase(plan: SeatPlan) async -> CheckoutState {
        errorMessage = nil
        
        guard let businessId = currentBusinessId else {
            errorMessage = "Missing business context."
            return .failed
        }
        
        // 🔥 BLOCK DOWNGRADE / SAME PLAN
        if let currentPlan = currentPlan,
           plan.extraSeats <= currentPlan.extraSeats {
            errorMessage = "You already have this plan or higher."
            return .failed
        }
        
        guard let product = product(for: plan) else {
            errorMessage = "Product not loaded."
            return .failed
        }
        
        isWorking = true
        defer { isWorking = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                
                let transaction = try checkVerified(verification)
                
                try await syncEntitlementToFirebase(
                    businessId: businessId,
                    transaction: transaction
                )
                
                await refreshEntitlementsFromApple()
                await transaction.finish()
                
                return .completed
                
            case .userCancelled:
                return .canceled
                
            case .pending:
                errorMessage = "Purchase pending approval."
                return .failed
                
            @unknown default:
                errorMessage = "Unknown purchase state."
                return .failed
            }
            
        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }
    
    // MARK: - Restore
    
    func restorePurchases() async -> Bool {
        isWorking = true
        errorMessage = nil
        
        defer { isWorking = false }
        
        do {
            try await AppStore.sync()
            await refreshEntitlementsFromApple()
            
            if let businessId = currentBusinessId,
               let transaction = await latestValidTransaction() {
                
                try await syncEntitlementToFirebase(
                    businessId: businessId,
                    transaction: transaction
                )
            }
            
            return true
            
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            return false
        }
    }
    
    private func latestValidTransaction() async -> Transaction? {
        
        var best: Transaction?
        var bestSeats = 0
        
        for await result in Transaction.currentEntitlements {
            
            guard let transaction = try? checkVerified(result) else { continue }
            guard let plan = SeatPlan(rawValue: transaction.productID) else { continue }
            
            if transaction.revocationDate != nil { continue }
            
            if let expiry = transaction.expirationDate,
               expiry < Date() {
                continue
            }
            
            if plan.extraSeats > bestSeats {
                bestSeats = plan.extraSeats
                best = transaction
            }
        }
        
        return best
    }
    
    func refreshEntitlementsFromApple() async {
        
        var bestPlan: SeatPlan?
        var bestExpiry: Date?
        var detectedGrace = false
        
        for await result in Transaction.currentEntitlements {
            
            guard let transaction = try? checkVerified(result) else { continue }
            guard let plan = SeatPlan(rawValue: transaction.productID) else { continue }
            
            if transaction.revocationDate != nil { continue }
            
            if let expiry = transaction.expirationDate {
                
                if expiry > Date() {
                    
                    if bestPlan == nil || plan.extraSeats > (bestPlan?.extraSeats ?? 0) {
                        bestPlan = plan
                        bestExpiry = expiry
                    }
                    
                } else {
                    detectedGrace = true
                }
            }
        }
        
        activeProductID = bestPlan?.rawValue
        activeExtraSeats = bestPlan?.extraSeats ?? 0
        
        renewalDate = bestExpiry
        isInGracePeriod = detectedGrace
    }
    
    // MARK: - Listener
    
    private func startTransactionListenerIfNeeded() {
        
        guard updatesTask == nil else { return }
        
        updatesTask = Task { [weak self] in
            guard let self else { return }
            
            for await result in Transaction.updates {
                
                guard !Task.isCancelled else { break }
                guard let transaction = try? self.checkVerified(result) else { continue }
                guard self.productIDs.contains(transaction.productID) else { continue }
                
                self.isWorking = true
                
                do {
                    if let businessId = self.currentBusinessId {
                        try await self.syncEntitlementToFirebase(
                            businessId: businessId,
                            transaction: transaction
                        )
                    }
                    
                    await self.refreshEntitlementsFromApple()
                    await transaction.finish()
                    
                } catch {
                    self.errorMessage = "Seat sync failed: \(error.localizedDescription)"
                }
                
                self.isWorking = false
            }
        }
    }
    
    // MARK: - Firebase
    
    private func syncEntitlementToFirebase(
        businessId: String,
        transaction: Transaction
    ) async throws {
        
        _ = try await functions
            .httpsCallable("verifyAppleSeatPurchase")
            .call([
                "businessId": businessId,
                "productId": transaction.productID
            ])
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "Verification", code: 1)
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Helpers
    
    func product(for plan: SeatPlan) -> Product? {
        products.first(where: { $0.id == plan.rawValue })
    }
    
    func isActive(plan: SeatPlan) -> Bool {
        activeProductID == plan.rawValue
    }
}

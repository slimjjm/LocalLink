import Foundation
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {

    static let shared = StoreKitManager()

    @Published var products: [Product] = []
    @Published var isPurchasing = false

    // Your App Store product ID
    private let productIds = [
        "locallink.staff.seat"
    ]

    init() {
        Task {
            await loadProducts()
        }
    }

    // MARK: Load Products

    func loadProducts() async {

        do {
            products = try await Product.products(for: productIds)
        } catch {
            print("❌ Failed loading products:", error)
        }
    }

    // MARK: Purchase

    func purchaseSeat() async throws -> String? {

        guard let product = products.first else {
            throw NSError(domain: "NoProduct", code: 0)
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()

        switch result {

        case .success(let verification):

            let transaction = try checkVerified(verification)

            // return transaction id so server can verify
            return String(transaction.id)

        case .userCancelled:
            return nil

        case .pending:
            print("⏳ Purchase pending")
            return nil

        default:
            return nil
        }
    }

    // MARK: Verify Transaction

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {

        switch result {
        case .unverified:
            throw NSError(domain: "Verification failed", code: 0)

        case .verified(let safe):
            return safe
        }
    }
}

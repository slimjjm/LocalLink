import Foundation
import FirebaseFunctions
import FirebaseFirestore
import StripePaymentSheet
import UIKit

@MainActor
final class StaffUnlockViewModel: ObservableObject {

    enum CheckoutState {
        case requiresPayment
        case completedWithoutPayment
        case failed
    }

    enum PayResult {
        case completed
        case canceled
        case failed(String)
    }

    @Published var isWorking = false
    @Published var errorMessage: String?

    private let functions = Functions.functions(region: "us-central1")
    private let db = Firestore.firestore()

    private var paymentSheet: PaymentSheet?

    // We store the target businessId so we can confirm entitlement changes after payment.
    private var currentBusinessId: String?
    private var expectedIncrementBy: Int = 1

    // MARK: - Start checkout (calls Cloud Function)

    func startCheckout(businessId: String, incrementBy: Int = 1) async -> CheckoutState {

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        currentBusinessId = businessId
        expectedIncrementBy = max(1, incrementBy)

        do {
            let result = try await functions
                .httpsCallable("createOrIncrementStaffSubscription")
                .call([
                    "businessId": businessId,
                    "incrementBy": expectedIncrementBy
                ])

            guard let data = result.data as? [String: Any] else {
                errorMessage = "Invalid server response."
                return .failed
            }

            let requiresPayment = data["requiresPayment"] as? Bool ?? false

            // ✅ If Stripe auto-charged (no PaymentSheet)
            if !requiresPayment {
                // Still wait briefly for webhook to sync entitlements so UI updates
                let ok = await waitForEntitlementsUpdate(businessId: businessId)
                if !ok {
                    // Not fatal — user paid/was charged, webhook may still be processing.
                    // But we surface a soft message to reduce confusion.
                    errorMessage = "Payment processed. Updating your seats… please refresh if it doesn’t update."
                }
                return .completedWithoutPayment
            }

            // ✅ Payment required: we must have these
            guard
                let customerId = data["customerId"] as? String,
                let ephemeralKey = data["ephemeralKey"] as? String,
                let clientSecret = data["clientSecret"] as? String
            else {
                errorMessage = "Missing payment parameters."
                return .failed
            }

            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "LocalLink"

            configuration.applePay = .init(
                merchantId: "merchant.com.locallink",
                merchantCountryCode: "GB"
            )

            configuration.customer = .init(
                id: customerId,
                ephemeralKeySecret: ephemeralKey
            )

            configuration.allowsDelayedPaymentMethods = false

            paymentSheet = PaymentSheet(
                paymentIntentClientSecret: clientSecret,
                configuration: configuration
            )

            return .requiresPayment

        } catch {
            errorMessage = error.localizedDescription
            return .failed
        }
    }

    // MARK: - Present payment sheet

    func presentPayment(completion: @escaping (PayResult) -> Void) {

        guard let paymentSheet else {
            completion(.failed("Payment sheet not ready."))
            return
        }

        guard let viewController = topViewController() else {
            completion(.failed("Unable to present checkout."))
            return
        }

        isWorking = true

        paymentSheet.present(from: viewController) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                self.isWorking = false

                switch result {
                case .completed:
                    completion(.completed)
                case .canceled:
                    completion(.canceled)
                case .failed(let error):
                    completion(.failed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Call this after successful payment (or auto-charge)

    func finalizeAfterSuccess() async -> Bool {
        guard let businessId = currentBusinessId else { return true }
        return await waitForEntitlementsUpdate(businessId: businessId)
    }

    // MARK: - Entitlements confirmation

    /// Waits up to ~10 seconds for Firestore entitlements to reflect an update
    /// (webhook lag protection so UI feels instant).
    private func waitForEntitlementsUpdate(businessId: String) async -> Bool {

        let ref = db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")

        // Capture baseline before payment
        var baselineExtra: Int = 0
        do {
            let snap = try await ref.getDocument()
            baselineExtra = (snap.data()?["extraStaffSlots"] as? Int) ?? 0
        } catch {
            // If we can't read baseline, still attempt to wait for any readable update
            baselineExtra = 0
        }

        // Poll: 5 tries over ~10 seconds
        let maxTries = 5
        for attempt in 1...maxTries {
            do {
                let snap = try await ref.getDocument()
                let data = snap.data() ?? [:]

                let extra = (data["extraStaffSlots"] as? Int) ?? 0
                let stripeStatus = (data["stripeStatus"] as? String) ?? ""

                // Success conditions:
                // - extra increased, OR
                // - status is active (covers edge cases)
                if extra >= baselineExtra + expectedIncrementBy || stripeStatus == "active" {
                    return true
                }
            } catch {
                // ignore and retry
            }

            // Backoff sleep: 1.0s, 1.5s, 2.0s, 2.5s, 3.0s (approx)
            let delayMs = 700 + (attempt * 500)
            try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
        }

        return false
    }

    // MARK: - UIKit helper

    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let root = window.rootViewController
        else { return nil }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

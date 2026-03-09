import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

final class BusinessBillingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var status: String = "Loading..."
    @Published var freeSeats: Int = 1
    @Published var paidSeats: Int = 0
    @Published var nextBillingDate: String = "-"
    @Published var restrictionMode: Bool = false
    @Published var isLoading = false
    @Published var errorMessage = ""

    // MARK: - Computed Properties

    var totalSeats: Int {
        freeSeats + paidSeats
    }

    var isActive: Bool {
        status.lowercased() == "active"
    }

    var seatDisplayString: String {
        "\(totalSeats) seats (\(freeSeats) free + \(paidSeats) paid)"
    }

    var restrictionWarningText: String? {
        guard restrictionMode else { return nil }
        return "Your subscription is restricted. Please update billing to restore full access."
    }

    // MARK: - Firebase

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    // MARK: - Load Billing Data

    func load(businessId: String) {

        isLoading = true
        errorMessage = ""

        db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")
            .getDocument { [weak self] snapshot, error in

                guard let self = self else { return }

                DispatchQueue.main.async {

                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }

                    guard let data = snapshot?.data() else {
                        self.errorMessage = "No billing data found."
                        return
                    }

                    self.freeSeats = data["freeStaffSlots"] as? Int ?? 1
                    self.paidSeats = data["extraStaffSlots"] as? Int ?? 0

                    let rawStatus = data["stripeStatus"] as? String ?? "free"
                    self.status = rawStatus.capitalized

                    self.restrictionMode = data["restrictionMode"] as? Bool ?? false

                    if let timestamp = data["currentPeriodEnd"] as? Timestamp {
                        let date = timestamp.dateValue()
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        self.nextBillingDate = formatter.string(from: date)
                    } else {
                        self.nextBillingDate = "-"
                    }
                }
            }
    }

    // MARK: - Open Stripe Billing Portal

    func openBillingPortal(completion: @escaping (URL?) -> Void) {

        functions.httpsCallable("createStripePortalLink")
            .call { [weak self] result, error in

                DispatchQueue.main.async {

                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        completion(nil)
                        return
                    }

                    guard
                        let data = result?.data as? [String: Any],
                        let urlString = data["url"] as? String,
                        let url = URL(string: urlString)
                    else {
                        completion(nil)
                        return
                    }

                    completion(url)
                }
            }
    }
}

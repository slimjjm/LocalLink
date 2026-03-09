import SwiftUI
import FirebaseFirestore
import FirebaseFunctions
import StoreKit

struct BusinessSubscriptionView: View {

    let businessId: String

    // MARK: State

    @State private var freeSeats = 1
    @State private var extraSeats = 0
    @State private var staffCount = 0
    @State private var stripeStatus = "free"
    @State private var restrictionMode = false

    @State private var isLoading = true
    @State private var isOpeningPortal = false
    @State private var errorMessage: String?

    @StateObject private var unlockVM = StaffUnlockViewModel()
    @State private var entitlementListener: ListenerRegistration?

    private let db = Firestore.firestore()
    private let functions = Functions.functions(region: "us-central1")

    private var totalSeats: Int {
        freeSeats + extraSeats
    }

    // MARK: Body

    var body: some View {

        ScrollView {

            VStack(spacing: 24) {

                if isLoading {

                    ProgressView("Loading subscription...")
                        .frame(maxWidth: .infinity)

                } else {

                    statusCard
                    seatCard

                    if restrictionMode {
                        restrictionBanner
                    }

                    actionButtons

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(AppColors.error)
                            .font(.footnote)
                    }

                    if let unlockError = unlockVM.errorMessage {
                        Text(unlockError)
                            .foregroundColor(AppColors.error)
                            .font(.footnote)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.background)
        .navigationTitle("Subscription")
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    // MARK: Status Card

    private var statusCard: some View {

        VStack(spacing: 8) {

            Text("Plan Status")
                .font(.headline)

            Text(displayStatus)
                .font(.title2.bold())
                .foregroundColor(statusColor)

        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
    }

    // MARK: Seat Card

    private var seatCard: some View {

        VStack(spacing: 10) {

            Text("Seat Usage")
                .font(.headline)

            Text("\(staffCount) / \(totalSeats)")
                .font(.title.bold())

            HStack {

                Text("Free: \(freeSeats)")
                Spacer()
                Text("Paid: \(extraSeats)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cardBackground)
    }

    // MARK: Restriction Banner

    private var restrictionBanner: some View {

        Text("Account restricted due to unresolved billing.")
            .font(.footnote)
            .foregroundColor(AppColors.error)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
            )
    }

    // MARK: Buttons

    private var actionButtons: some View {

        VStack(spacing: 14) {

            Text("Each additional staff seat costs £4.99 per month.\nCancel anytime in Apple Subscriptions.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await addSeat() }
            } label: {

                if unlockVM.isWorking {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Unlock another staff member\n£4.99 per month")
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
            .primaryButton()
            .disabled(restrictionMode)

            if extraSeats > 0 {

                Button {
                    removeSeat()
                } label: {
                    Text("Remove Staff Seat")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button("Restore Purchases") {
                Task {
                    try? await AppStore.sync()
                }
            }
            .buttonStyle(.bordered)

            Button {
                openBillingPortal()
            } label: {

                if isOpeningPortal {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Manage Billing")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: UI Helpers

    private var cardBackground: some View {

        RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemBackground))
    }

    private var displayStatus: String {

        switch stripeStatus {

        case "active": return "Active"
        case "past_due": return "Payment Required"
        case "canceled": return "Cancelled"
        default: return extraSeats > 0 ? "Active" : "Free Plan"
        }
    }

    private var statusColor: Color {

        switch stripeStatus {

        case "active": return AppColors.success
        case "past_due": return AppColors.error
        case "canceled": return AppColors.error
        default: return .secondary
        }
    }

    // MARK: Firestore Listener

    private func startListening() {

        entitlementListener?.remove()

        let entRef = db.collection("businesses")
            .document(businessId)
            .collection("entitlements")
            .document("default")

        entitlementListener = entRef.addSnapshotListener { snap, error in

            if let error {
                self.errorMessage = error.localizedDescription
                return
            }

            guard let data = snap?.data() else { return }

            DispatchQueue.main.async {

                freeSeats = data["freeStaffSlots"] as? Int ?? 1
                extraSeats = data["extraStaffSlots"] as? Int ?? 0
                stripeStatus = data["stripeStatus"] as? String ?? "free"
                restrictionMode = data["restrictionMode"] as? Bool ?? false

                refreshStaffCount()
            }
        }
    }

    private func stopListening() {

        entitlementListener?.remove()
        entitlementListener = nil
    }

    private func refreshStaffCount() {

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { snap, error in

                if let error {
                    errorMessage = error.localizedDescription
                }

                staffCount = snap?.documents.count ?? 0
                isLoading = false
            }
    }

    // MARK: Actions

    private func addSeat() async {

        let state = await unlockVM.startCheckout(
            businessId: businessId,
            incrementBy: 1
        )

        switch state {

        case .completedWithoutPayment:
            break

        case .requiresPayment:
            unlockVM.presentPayment { _ in }

        case .failed:
            errorMessage = unlockVM.errorMessage
        }
    }

    private func removeSeat() {

        functions.httpsCallable("decrementStaffSubscriptionQuantity")
            .call(["businessId": businessId]) { _, error in

                if let error {
                    errorMessage = error.localizedDescription
                }
            }
    }

    private func openBillingPortal() {

        isOpeningPortal = true

        functions.httpsCallable("createStripePortalLink")
            .call(["businessId": businessId]) { result, error in

                isOpeningPortal = false

                if let error {
                    errorMessage = error.localizedDescription
                    return
                }

                if let dict = result?.data as? [String: Any],
                   let urlString = dict["url"] as? String,
                   let url = URL(string: urlString) {

                    UIApplication.shared.open(url)
                }
            }
    }
}

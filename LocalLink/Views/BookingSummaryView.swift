import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseFunctions
import StripePaymentSheet

struct BookingSummaryView: View {

    // MARK: - Inputs
    let businessId: String
    let serviceId: String
    let staffId: String
    let date: Date
    let time: Date
    let customerAddress: String?

    @EnvironmentObject private var nav: NavigationState

    // MARK: - Loaded data
    @State private var service: BusinessService?
    @State private var staff: Staff?
    @State private var serviceArea: String = ""

    // MARK: - UI State
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // MARK: - Stripe
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentIntentId: String?

    private let bookingService = BookingService()
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 24) {

            Text("Booking Summary")
                .font(.largeTitle.bold())

            if let service, let staff {
                summaryView(service: service, staff: staff)
            } else {
                ProgressView("Loading booking details…")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button(action: startPaymentFlow) {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Confirm booking")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || service == nil || staff == nil)
        }
        .padding()
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadData)
    }

    // MARK: - Summary UI

    private func summaryView(service: BusinessService, staff: Staff) -> some View {
        let locationText = customerAddress ?? serviceArea

        return VStack(alignment: .leading, spacing: 12) {
            row("Service", service.name)
            row("Staff", staff.name)
            if !locationText.isEmpty {
                row("Location", locationText)
            }
            row("Price", String(format: "£%.2f", service.price))
            row("Duration", "\(service.durationMinutes) mins")
            row("Date", date.formatted(date: .long, time: .omitted))
            row("Time", time.formatted(date: .omitted, time: .shortened))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Load Firestore Data

    private func loadData() {

        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snapshot, _ in
                self.service = try? snapshot?.data(as: BusinessService.self)
            }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snapshot, _ in
                self.staff = try? snapshot?.data(as: Staff.self)
            }

        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in
                self.serviceArea =
                    snapshot?.data()?["serviceArea"] as? String ?? ""
            }
    }

    // MARK: - Payment Flow

    private func startPaymentFlow() {

        guard let service else { return }

        isSubmitting = true
        errorMessage = nil

        let amount = Int(service.price * 100)

        let functions = Functions.functions(region: "us-central1")

        functions.httpsCallable("createPaymentIntent")
            .call([
                "amount": amount,
                "currency": "gbp"
            ]) { result, error in

                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isSubmitting = false
                    }
                    return
                }

                guard
                    let data = result?.data as? [String: Any],
                    let clientSecret = data["clientSecret"] as? String,
                    let intentId = data["paymentIntentId"] as? String
                else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Payment setup failed"
                        self.isSubmitting = false
                    }
                    return
                }

                var config = PaymentSheet.Configuration()
                config.merchantDisplayName = "LocalLink"

                self.paymentIntentId = intentId
                self.paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: clientSecret,
                    configuration: config
                )

                DispatchQueue.main.async {
                    self.presentPaymentSheet()
                }
            }
    }
    
    private func presentPaymentSheet() {

        guard let paymentSheet else { return }

        paymentSheet.present(from: UIApplication.shared.windows.first!.rootViewController!) { result in

            switch result {

            case .completed:
                confirmBooking()

            case .failed(let error):
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                }

            case .canceled:
                DispatchQueue.main.async {
                    self.isSubmitting = false
                }
            }
        }
    }

    // MARK: - Confirm Booking

    private func confirmBooking() {

        guard let service,
              let staff,
              let user = Auth.auth().currentUser else {
            return
        }

        isSubmitting = true
        errorMessage = nil

        let endTime = Calendar.current.date(
            byAdding: .minute,
            value: service.durationMinutes,
            to: time
        )!

        let name = user.displayName ?? "Customer"

        bookingService.confirmBooking(
            businessId: businessId,
            customerId: user.uid,
            customerName: name,
            customerAddress: customerAddress ?? "Not Provided",
            service: service,
            staff: staff,
            location: serviceArea,
            date: date,
            startTime: time,
            endTime: endTime,
            paymentIntentId: paymentIntentId
        ) { result in

            DispatchQueue.main.async {
                self.isSubmitting = false

                switch result {
                case .success:
                    self.nav.path.append(
                        .bookingSuccess(businessId: businessId)
                    )
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}


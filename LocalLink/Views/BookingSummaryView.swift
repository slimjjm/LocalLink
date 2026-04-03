import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseFirestoreSwift
import StripePaymentSheet

struct BookingSummaryView: View {
    
    let businessId: String
    let serviceId: String
    let staffId: String
    let slotId: String
    let date: Date
    let time: Date
    let customerAddress: String?
    
    @EnvironmentObject private var nav: NavigationState
    
    @State private var service: BusinessService?
    @State private var staff: Staff?
    @State private var serviceArea: String = ""
    
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    @State private var paymentSheet: PaymentSheet?
    @State private var bookingId: String?
    
    private let functions = Functions.functions(region: "us-central1")
    private let db = Firestore.firestore()
    
    var body: some View {
        
        VStack(spacing: 24) {
            
            Text("Booking Summary")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)
            
            if let service, let staff {
                summaryView(service: service, staff: staff)
            } else {
                ProgressView("Loading booking details…")
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(AppColors.error)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                startPaymentFlow()
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Pay & confirm booking")
                        .frame(maxWidth: .infinity)
                }
            }
            .primaryButton()
            .disabled(isSubmitting || service == nil || staff == nil)
            
            Spacer()
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
        .onAppear(perform: loadData)
    }
    
    // MARK: Load
    
    private func loadData() {
        
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snap, _ in
                self.service = try? snap?.data(as: BusinessService.self)
            }
        
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snap, _ in
                self.staff = try? snap?.data(as: Staff.self)
            }
        
        db.collection("businesses")
            .document(businessId)
            .getDocument { snap, _ in
                self.serviceArea = snap?.data()?["serviceArea"] as? String ?? ""
            }
    }
    @ViewBuilder
    private func summaryView(service: BusinessService, staff: Staff) -> some View {
        
        let enteredAddress = (customerAddress ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let locationText = enteredAddress.isEmpty ? serviceArea : enteredAddress
        
        VStack(alignment: .leading, spacing: 12) {
            
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
    // MARK: PAYMENT
    
    private func startPaymentFlow() {
        
        print("🚀 START PAYMENT FLOW")
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please log in to book"
            return
        }

        guard !user.isAnonymous else {
            errorMessage = "Please log in to book"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        let payload: [String: Any] = [
            "businessId": businessId,
            "staffId": staffId,
            "serviceId": serviceId,
            "slotId": slotId,
            "customerName": user.displayName ?? "Customer",
            "customerAddress": customerAddress ?? ""
        ]
        
        print("📦 FUNCTION PAYLOAD:", payload)
        
        functions.httpsCallable("createBookingPaymentIntent")
            .call(payload) { result, error in
                
                print("📩 FUNCTION CALLBACK TRIGGERED")
                
                // 🔴 ERROR
                if let error = error as NSError? {
                    print("🔥 FUNCTION ERROR:")
                    print("Code:", error.code)
                    print("Message:", error.localizedDescription)
                    print("UserInfo:", error.userInfo)
                    
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isSubmitting = false
                    }
                    return
                }
                
                // 🔍 RAW RESPONSE
                print("🔥 RAW RESPONSE:", result?.data ?? "nil")
                
                guard let raw = result?.data else {
                    print("❌ NO DATA RETURNED")
                    self.fail("No response from server")
                    return
                }
                
                var parsed: [String: Any]?
                
                // Case 1: direct dictionary
                if let dict = raw as? [String: Any] {
                    parsed = dict
                }
                
                // Case 2: wrapped in "result"
                if let wrapper = raw as? [String: Any],
                   let inner = wrapper["result"] as? [String: Any] {
                    parsed = inner
                }
                
                guard let data = parsed else {
                    print("❌ FAILED TO PARSE RESPONSE")
                    self.fail("Invalid server response")
                    return
                }
                
                print("✅ PARSED DATA:", data)
                
                guard let clientSecret = data["clientSecret"] as? String else {
                    print("❌ MISSING clientSecret")
                    self.fail("Missing clientSecret")
                    return
                }
                
                guard let bookingId = data["bookingId"] as? String else {
                    print("❌ MISSING bookingId")
                    self.fail("Missing bookingId")
                    return
                }
                
                print("💳 CLIENT SECRET:", clientSecret)
                print("📄 BOOKING ID:", bookingId)
                
                self.bookingId = bookingId
                
                var config = PaymentSheet.Configuration()
                config.merchantDisplayName = "LocalLink"
                config.returnURL = "locallink://stripe-redirect"
                
                DispatchQueue.main.async {
                    print("🎯 INITIALISING PAYMENT SHEET")
                    
                    self.paymentSheet = PaymentSheet(
                        paymentIntentClientSecret: clientSecret,
                        configuration: config
                    )
                    
                    self.presentPaymentSheet()
                }
            }
    }
    
    private func presentPaymentSheet() {
        
        print("📲 PRESENTING PAYMENT SHEET")
        
        guard let paymentSheet else {
            print("❌ PAYMENT SHEET NIL")
            return
        }
        
        guard let rootVC = UIApplication.shared.topMostViewController() else {
            print("❌ ROOT VC NIL")
            return
        }
        
        paymentSheet.present(from: rootVC) { result in
            DispatchQueue.main.async {
                
                print("📊 PAYMENT RESULT:", result)
                
                switch result {
                    
                case .completed:
                    print("✅ PAYMENT COMPLETED")
                    self.listenForBookingConfirmation()
                    
                case .canceled:
                    print("⚠️ PAYMENT CANCELLED")
                    self.isSubmitting = false
                    
                case .failed(let error):
                    print("❌ PAYMENT FAILED:", error.localizedDescription)
                    self.errorMessage = error.localizedDescription
                    self.isSubmitting = false
                }
            }
        }
    }
    
    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isSubmitting = false
        }
    }
    
    // MARK: Confirmation
    
    private func listenForBookingConfirmation() {
        
        guard let bookingId else { return }
        
        print("👂 LISTENING FOR BOOKING CONFIRMATION:", bookingId)
        
        db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snap, _ in
                
                guard let data = snap?.data() else { return }
                let status = data["status"] as? String ?? ""
                
                print("📡 BOOKING STATUS:", status)
                
                if status == "confirmed" {
                    DispatchQueue.main.async {
                        print("🎉 BOOKING CONFIRMED")
                        self.isSubmitting = false
                        self.nav.path.append(
                            .bookingSuccess(
                                businessId: self.businessId,
                                bookingId: bookingId
                            )
                        )
                    }
                }
            }
    }
}

// MARK: VC helper

private extension UIApplication {
    
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        
        let baseVC = base ??
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
        
        if let nav = baseVC as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        
        if let tab = baseVC as? UITabBarController,
           let selected = tab.selectedViewController {
            return topMostViewController(base: selected)
        }
        
        if let presented = baseVC?.presentedViewController {
            return topMostViewController(base: presented)
        }
        
        return baseVC
    }
}

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
    
    // MARK: Summary
    
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
        
        HStack(alignment: .top) {
            
            Text(label)
                .foregroundColor(AppColors.charcoal)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    // MARK: Load Data
    
    private func loadData() {
        
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snap, error in
                
                if let error {
                    print("❌ Failed loading service:", error.localizedDescription)
                    return
                }
                
                guard let snap else { return }
                self.service = try? snap.data(as: BusinessService.self)
            }
        
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snap, error in
                
                if let error {
                    print("❌ Failed loading staff:", error.localizedDescription)
                    return
                }
                
                guard let snap else { return }
                self.staff = try? snap.data(as: Staff.self)
            }
        
        db.collection("businesses")
            .document(businessId)
            .getDocument { snap, error in
                
                if let error {
                    print("❌ Failed loading business:", error.localizedDescription)
                    return
                }
                
                guard let snap else { return }
                self.serviceArea = snap.data()?["serviceArea"] as? String ?? ""
            }
    }
    
    // MARK: Payment Flow
    
    private func startPaymentFlow() {
        
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please wait… signing in"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        functions.httpsCallable("createBookingPaymentIntent")
            .call([
                "businessId": businessId,
                "staffId": staffId,
                "serviceId": serviceId,
                "slotId": slotId,
                "customerName": user.displayName ?? "Customer",
                "customerAddress": customerAddress ?? ""
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
                    let bookingId = data["bookingId"] as? String
                else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Payment setup failed"
                        self.isSubmitting = false
                    }
                    return
                }
                
                self.bookingId = bookingId
                
                var config = PaymentSheet.Configuration()
                config.merchantDisplayName = "LocalLink"
                
                DispatchQueue.main.async {
                    self.paymentSheet = PaymentSheet(
                        paymentIntentClientSecret: clientSecret,
                        configuration: config
                    )
                    self.presentPaymentSheet()
                }
            }
    }
    
    // MARK: Present Stripe
    
    private func presentPaymentSheet() {
        
        guard let paymentSheet else { return }
        
        guard let vc = UIApplication.shared.topMostViewController() else {
            self.errorMessage = "Unable to present payment sheet"
            self.isSubmitting = false
            return
        }
        
        paymentSheet.present(from: vc) { result in
            
            switch result {
                
            case .completed:
                
                DispatchQueue.main.async {
                    self.listenForBookingConfirmation()
                }
                
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
    
    // MARK: Wait for Webhook Confirmation
    
    private func listenForBookingConfirmation() {
        
        guard let bookingId else { return }
        
        db.collection("bookings")
            .document(bookingId)
            .addSnapshotListener { snap, error in
                
                guard let data = snap?.data() else { return }
                
                let status = data["status"] as? String ?? ""
                
                if status == "confirmed" {
                    
                    DispatchQueue.main.async {
                        
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

// MARK: UIKit Helper

private extension UIApplication {
    
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        
        let baseVC: UIViewController? = {
            
            if let base { return base }
            
            return connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }()
        
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

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingSummaryView: View {

    let businessId: String
    let serviceId: String
    let staffId: String
    let date: Date
    let time: Date

    @EnvironmentObject private var nav: NavigationState

    @State private var service: BusinessService?
    @State private var staff: Staff?

    // ✅ Safe static location (prevents spinner + reviewer dead-end)
    @State private var location: String = "At business location"

    @State private var lastVerificationEmailSentAt: Date?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showAuthCTA = false

    private let bookingService = BookingService()
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 24) {

            Text("Booking Summary")
                .font(.largeTitle.bold())

            if let service, let staff {
                summary(service: service, staff: staff, location: location)
            } else {
                ProgressView("Loading details…")
            }

            if let errorMessage {
                VStack(spacing: 12) {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)

                    if showAuthCTA {
                        Button("Log in or Create account") {
                            nav.path.append(.startSelection)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Button(action: confirmBooking) {
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

    private func summary(
        service: BusinessService,
        staff: Staff,
        location: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row("Service", service.name)
            row("Staff", staff.name)
            row("Location", location)
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

    // MARK: - Load data (Apple-safe)

    private func loadData() {

        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.service = try? snapshot?.data(as: BusinessService.self)
                }
            }

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.staff = try? snapshot?.data(as: Staff.self)
                }
            }
    }

    // MARK: - Confirm booking

    private func confirmBooking() {

        guard let service, let staff else { return }

        errorMessage = nil
        showAuthCTA = false

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in to make a booking."
            showAuthCTA = true
            return
        }

        if user.isAnonymous {
            errorMessage = "Please create an account to make a booking."
            showAuthCTA = true
            return
        }

        if !user.isEmailVerified {

            let now = Date()
            if let lastSent = lastVerificationEmailSentAt,
               now.timeIntervalSince(lastSent) < 60 {
                errorMessage = "Please verify your email before making a booking."
                return
            }

            user.sendEmailVerification()
            lastVerificationEmailSentAt = now

            errorMessage = "Please verify your email. We’ve just sent you a verification email."
            return
        }

        isSubmitting = true

        let endTime = Calendar.current.date(
            byAdding: .minute,
            value: service.durationMinutes,
            to: time
        )!

        bookingService.confirmBooking(
            businessId: businessId,
            customerId: user.uid,
            service: service,
            staff: staff,
            location: location,
            date: date,
            startTime: time,
            endTime: endTime
        ) { result in
            DispatchQueue.main.async {
                self.isSubmitting = false
                if case .success = result {
                    self.nav.path.append(.bookingSuccess)
                } else if case .failure(let error) = result {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}


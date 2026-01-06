import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BookingSummaryView: View {

    // MARK: - Inputs (IDs only)
    let businessId: String
    let serviceId: String
    let staffId: String
    let date: Date
    let time: Date

    // MARK: - Environment
    @EnvironmentObject private var nav: NavigationState

    // MARK: - State
    @State private var service: BusinessService?
    @State private var staff: Staff?
    @State private var location: String?

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    // MARK: - Services
    private let bookingService = BookingService()
    private let db = Firestore.firestore()

    // MARK: - View
    var body: some View {
        VStack(spacing: 24) {

            Text("Booking Summary")
                .font(.largeTitle.bold())

            if let service, let staff, let location {
                summary(service: service, staff: staff, location: location)
            } else {
                ProgressView("Loading details…")
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                confirmBooking()
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Confirm booking")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                isSubmitting ||
                service == nil ||
                staff == nil ||
                location == nil
            )
        }
        .padding()
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
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
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Data loading
    private func loadData() {

        // Service
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .document(serviceId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.service = try? snapshot?.data(as: BusinessService.self)
                }
            }

        // Staff
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.staff = try? snapshot?.data(as: Staff.self)
                }
            }

        // Business location
        db.collection("businesses")
            .document(businessId)
            .getDocument { snapshot, _ in
                DispatchQueue.main.async {
                    self.location = snapshot?.get("address") as? String
                }
            }
    }

    // MARK: - Booking
    private func confirmBooking() {
        guard let service, let staff, let location else { return }

        errorMessage = nil
        isSubmitting = true

        ensureUserId { uid in
            let endTime = Calendar.current.date(
                byAdding: .minute,
                value: service.durationMinutes,
                to: time
            )!

            bookingService.confirmBooking(
                businessId: businessId,
                customerId: uid,
                service: service,
                staff: staff,
                location: location,
                date: date,
                startTime: time,
                endTime: endTime
            ) { result in
                DispatchQueue.main.async {
                    self.isSubmitting = false

                    switch result {
                    case .success:
                        self.nav.path.append(AppRoute.bookingSuccess)


                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Auth
    private func ensureUserId(completion: @escaping (String) -> Void) {
        if let uid = Auth.auth().currentUser?.uid {
            completion(uid)
            return
        }

        Auth.auth().signInAnonymously { result, error in
            DispatchQueue.main.async {
                if let uid = result?.user.uid {
                    completion(uid)
                } else {
                    self.isSubmitting = false
                    self.errorMessage =
                        error?.localizedDescription ?? "Unable to sign in."
                }
            }
        }
    }
}


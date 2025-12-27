import SwiftUI
import FirebaseAuth

struct BookingSummaryView: View {

    // MARK: - Inputs
    let businessId: String
    let service: Service
    let staff: Staff
    let date: Date          // selected day
    let time: Date          // selected start time

    // MARK: - State
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var navigateSuccess = false

    private let bookingService = BookingService()

    var body: some View {
        VStack(spacing: 20) {

            Text("Booking Summary")
                .font(.largeTitle.bold())

            VStack(alignment: .leading, spacing: 10) {
                Text("Service: \(service.name)")
                Text("Staff: \(staff.name)")
                Text("Price: £\(service.price, specifier: "%.2f")")
                Text("Duration: \(service.durationMinutes) minutes")
                Text("Date: \(dateFormatter.string(from: date))")
                Text("Time: \(timeFormatter.string(from: time)) – \(timeFormatter.string(from: endTime))")
            }

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            Button(isSaving ? "Confirming…" : "Confirm booking") {
                confirmBooking()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)

            NavigationLink(
                destination: BookingSuccessView(),
                isActive: $navigateSuccess
            ) {
                EmptyView()
            }
        }
        .padding()
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Derived

    private var endTime: Date {
        time.addingTimeInterval(TimeInterval(service.durationMinutes * 60))
    }

    // MARK: - Actions

    private func confirmBooking() {
        guard let customerId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to book."
            return
        }

        isSaving = true
        errorMessage = nil

        bookingService.confirmBooking(
            businessId: businessId,
            customerId: customerId,
            service: service,
            staff: staff,
            date: date,
            startTime: time,
            endTime: endTime
        ) { result in
            DispatchQueue.main.async {
                isSaving = false

                switch result {
                case .success:
                    navigateSuccess = true
                case .failure:
                    errorMessage = "Failed to confirm booking. Please try again."
                }
            }
        }
    }

    // MARK: - Formatters

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df
    }

    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.timeStyle = .short
        return df
    }
}

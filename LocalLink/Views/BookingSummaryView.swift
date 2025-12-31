import SwiftUI
import FirebaseAuth

struct BookingSummaryView: View {

    // MARK: - Inputs
    let businessId: String
    let service: BusinessService
    let staff: Staff
    let date: Date
    let time: Date

    // MARK: - State
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    // MARK: - Services
    private let bookingService = BookingService()

    // MARK: - View
    var body: some View {
        VStack(spacing: 24) {

            // Header
            Text("Booking Summary")
                .font(.largeTitle.bold())

            // Details
            VStack(alignment: .leading, spacing: 10) {
                summaryRow(label: "Service", value: service.name)
                summaryRow(label: "Staff", value: staff.name)
                summaryRow(
                    label: "Price",
                    value: String(format: "£%.2f", service.price)
                )
                summaryRow(
                    label: "Duration",
                    value: "\(service.durationMinutes) minutes"
                )
                summaryRow(
                    label: "Date",
                    value: dateFormatter.string(from: date)
                )
                summaryRow(
                    label: "Time",
                    value: "\(timeFormatter.string(from: time)) – \(timeFormatter.string(from: endTime))"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Error
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            // Confirm Button
            Button {
                confirmBooking()
            } label: {
                if isSubmitting {
                    ProgressView()
                } else {
                    Text("Confirm booking")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
        .padding()
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSuccess) {
            BookingSuccessView()
        }
    }

    // MARK: - Helpers

    private var endTime: Date {
        time.addingTimeInterval(TimeInterval(service.durationMinutes * 60))
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Actions

    private func confirmBooking() {
        guard let customerId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be logged in to book."
            return
        }

        guard !isSubmitting else { return }

        isSubmitting = true
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
                isSubmitting = false
                switch result {
                case .success:
                    showSuccess = true
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

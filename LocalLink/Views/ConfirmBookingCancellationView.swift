import SwiftUI

struct ConfirmBookingCancellationView: View {

    let conflicts: [BookingConflict]
    let onConfirm: () -> Void
    let onBack: () -> Void

    @State private var confirmed = false

    var body: some View {

        VStack(spacing: 20) {

            Text("Confirm Cancellation")
                .font(.title)

            Text("\(conflicts.count) booking(s) will be cancelled.")
                .multilineTextAlignment(.center)

            Toggle(
                "I understand these bookings will be cancelled and customers will be notified.",
                isOn: $confirmed
            )

            Button("Cancel \(conflicts.count) Booking(s) and Apply Block") {
                onConfirm()
            }
            .disabled(!confirmed)
            .buttonStyle(.borderedProminent)

            Button("Go Back", action: onBack)
                .padding(.top)
        }
        .padding()
    }
}

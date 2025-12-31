import SwiftUI

struct BookingSuccessView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Booking Confirmed")
                .font(.largeTitle.bold())

            Text("Your appointment has been successfully booked.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("View my bookings") {
                dismissToRoot()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    private func dismissToRoot() {
        dismiss()
        dismiss()
        dismiss()
    }
}

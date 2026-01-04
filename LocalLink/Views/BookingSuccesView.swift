import SwiftUI

struct BookingSuccessView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            VStack(spacing: 8) {
                Text("Booking confirmed")
                    .font(.largeTitle.bold())

                Text("Your appointment has been successfully booked.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("You’ll find the details in My bookings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Button {
                dismissToRoot()
            } label: {
                HStack {
                    Text("View my bookings")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 12)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Navigation

    private func dismissToRoot() {
        dismiss()
        dismiss()
        dismiss()
    }
}


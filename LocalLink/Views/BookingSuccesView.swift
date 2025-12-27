import SwiftUI

struct BookingSuccessView: View {

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

            NavigationLink("View my bookings") {
                CustomerBookingsView()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
}



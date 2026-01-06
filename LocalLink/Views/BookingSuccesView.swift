import SwiftUI

struct BookingSuccessView: View {

    @EnvironmentObject private var nav: NavigationState

    var body: some View {
        VStack(spacing: 28) {

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.green)

            // Main message
            VStack(spacing: 10) {
                Text("Booking confirmed")
                    .font(.largeTitle.bold())

                Text("Your appointment has been successfully booked.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Taking you back to My Bookings…")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Optional secondary action (fast exit)
            Button {
                nav.path.append(AppRoute.customerHome)
            } label: {
                Text("View my bookings")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

        }
        .padding()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                nav.path.append(AppRoute.customerHome)
            }
        }
    }
}

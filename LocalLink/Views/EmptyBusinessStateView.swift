import SwiftUI

struct EmptyBusinessStateView: View {

    var body: some View {
        VStack(spacing: 20) {

            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No business yet")
                .font(.title.bold())

            Text("Create your business profile to start accepting bookings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            NavigationLink {
                BusinessOnboardingView()
            } label: {
                Text("Create Business")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


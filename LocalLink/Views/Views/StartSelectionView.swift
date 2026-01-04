import SwiftUI

struct StartSelectionView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var fadeIn = false

    var body: some View {
        VStack(spacing: 40) {

            header

            VStack(spacing: 22) {

                // BUSINESS
                Button {
                    authManager.beginBusinessOnboarding()
                } label: {
                    selectionCard(
                        icon: "briefcase.fill",
                        title: "I am a Business",
                        subtitle: "Manage bookings, services, and customers"
                    )
                }

                // CUSTOMER
                Button {
                    authManager.setRole(.customer)
                } label: {
                    selectionCard(
                        icon: "person.3.fill",
                        title: "I am a Customer",
                        subtitle: "Find local services and book instantly"
                    )
                }
            }

            Spacer()
        }
        .padding()
        .opacity(fadeIn ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) {
                fadeIn = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "link.circle.fill")
                .resizable()
                .frame(width: 90, height: 90)
                .foregroundColor(.blue)

            Text("Welcome to LocalLink")
                .font(.largeTitle.bold())

            Text("How can we help you today?")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Selection Card

    private func selectionCard(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 20) {

            Image(systemName: icon)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }
}

import SwiftUI

struct RoleSelectionView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {

        VStack(spacing: 36) {

            Spacer()

            // MARK: - Header

            VStack(spacing: 14) {

                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Welcome to LocalLink")
                    .font(.largeTitle.bold())
                    .foregroundColor(AppColors.charcoal)

                Text("What would you like to do today?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // MARK: - Options

            VStack(spacing: 18) {

                roleCard(
                    icon: "person.3.fill",
                    title: "Find Local Services",
                    subtitle: "Book trusted professionals near you",
                    isPrimary: true
                ) {
                    authManager.setRole(.customer)
                }

                roleCard(
                    icon: "briefcase.fill",
                    title: "Run My Business",
                    subtitle: "Manage bookings, staff and availability",
                    isPrimary: false
                ) {
                    authManager.setRole(.business)
                }
            }

            Spacer()

        }
        .padding(24)
        .background(AppColors.background.ignoresSafeArea())
    }

    // MARK: - Role Card

    private func roleCard(
        icon: String,
        title: String,
        subtitle: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 20) {

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .frame(width: 54, height: 54)
                    .background(
                        isPrimary
                        ? AppColors.primary.opacity(0.15)
                        : Color.gray.opacity(0.15)
                    )
                    .foregroundColor(
                        isPrimary
                        ? AppColors.primary
                        : AppColors.primary                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {

                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.charcoal)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

struct RoleSelectionView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 32) {

            Spacer()

            VStack(spacing: 12) {
                Text("Welcome")
                    .font(.largeTitle.bold())

                Text("How will you use LocalLink?")
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {

                Button {
                    authManager.setRole(.customer)
                } label: {
                    Label("I'm a Customer", systemImage: "person")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    authManager.setRole(.business)
                } label: {
                    Label("I'm a Business", systemImage: "briefcase")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
    }
}


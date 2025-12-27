import SwiftUI

struct WelcomeView: View {

    @AppStorage("userType") private var userType: String = ""

    var body: some View {
        VStack(spacing: 30) {

            Spacer()

            Text("Welcome")
                .font(.largeTitle.bold())

            Text("Choose how you want to continue")
                .foregroundColor(.secondary)

            Button {
                userType = "customer"
            } label: {
                Text("I am a Customer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                userType = "business"
            } label: {
                Text("I am a Business")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .onAppear {
            // DEV MODE: always force role selection
            UserDefaults.standard.removeObject(forKey: "userType")
        }
    }
}

#Preview {
    WelcomeView()
}

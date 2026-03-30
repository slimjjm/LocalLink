import SwiftUI
import FirebaseFunctions

struct StripeConnectView: View {

    @State private var isLoading = false
    @State private var error: String?

    private let functions = Functions.functions(region: "us-central1")

    var body: some View {

        VStack(spacing: 24) {

            Text("Connect Stripe")
                .font(.largeTitle.bold())

            Text("Connect your Stripe account to receive payouts from LocalLink bookings.")
                .multilineTextAlignment(.center)

            if let error {
                Text(error)
                    .foregroundColor(.red)
            }

            Button {

                startConnectFlow()

            } label: {

                if isLoading {
                    ProgressView()
                } else {
                    Text("Connect Stripe")
                }

            }
            .primaryButton()

            Spacer()
        }
        .padding()
    }

    // MARK: - Start onboarding

    private func startConnectFlow() {

        isLoading = true

        functions.httpsCallable("startStripeOnboarding")
            .call { result, error in

                if let error {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard
                    let data = result?.data as? [String: Any],
                    let urlString = data["url"] as? String,
                    let url = URL(string: urlString)
                else {
                    self.error = "Invalid Stripe link"
                    self.isLoading = false
                    return
                }

                UIApplication.shared.open(url)
                self.isLoading = false
            }
    }
}

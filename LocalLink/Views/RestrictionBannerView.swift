import SwiftUI
import FirebaseFunctions

struct RestrictionBannerView: View {

    let businessId: String

    @State private var isLoading = false
    @State private var errorMessage: String?

    private let functions = Functions.functions(region: "us-central1")

    var body: some View {
        VStack(spacing: 12) {

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)

                Text("Billing issue detected")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            Text("Your account is temporarily restricted. Update your payment method to restore full access.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.95))

            Button {
                openBillingPortal()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Fix Billing")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(8)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding()
        .background(Color.red.opacity(0.85))
        .cornerRadius(12)
    }

    private func openBillingPortal() {
        isLoading = true
        errorMessage = nil

        functions
            .httpsCallable("createStripePortalLink")
            .call { result, error in

                isLoading = false

                if let error {
                    errorMessage = error.localizedDescription
                    return
                }

                if let urlString = (result?.data as? [String: Any])?["url"] as? String,
                   let url = URL(string: urlString) {

                    UIApplication.shared.open(url)
                }
            }
    }
}

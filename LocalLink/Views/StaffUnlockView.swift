import SwiftUI
import StripePaymentSheet

struct StaffUnlockView: View {

    let businessId: String
    let onSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = StaffUnlockViewModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock more staff")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Add an extra staff slot for £4.99 per month. You can increase or change this model later without rebuilding your gate logic.")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(spacing: 12) {

                    Button {
                        Task { await unlockOneSeat() }
                    } label: {
                        if vm.isWorking {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        } else {
                            Text("Unlock 1 staff slot (£4.99/month)")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isWorking)

                    Text("This purchase is enforced server-side. Staff creation is blocked unless your entitlements allow it.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let err = vm.errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Flow

    private func unlockOneSeat() async {
        let state = await vm.startCheckout(businessId: businessId, incrementBy: 1)
        print("🧠 Checkout state:", state)

        switch state {

        case .requiresPayment:
            // presentPayment is callback-based; don't await it
            vm.presentPayment { result in
                switch result {

                case .completed:
                    Task {
                        _ = await vm.finalizeAfterSuccess()
                        onSuccess()
                        dismiss()
                    }

                case .canceled:
                    break

                case .failed(let message):
                    vm.errorMessage = message
                }
            }

        case .completedWithoutPayment:
            // Auto-charged or no immediate payment UI needed — still wait for webhook sync
            _ = await vm.finalizeAfterSuccess()
            onSuccess()
            dismiss()

        case .failed:
            break
        }
    }
}

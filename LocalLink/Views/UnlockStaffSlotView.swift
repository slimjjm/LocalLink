import SwiftUI

struct UnlockStaffSlotView: View {

    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {

            VStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)

                Text("Add another staff member")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            VStack(spacing: 12) {
                Text(
                    "Your plan includes 1 staff rota. Unlocking an extra slot lets you add another staff member and take more bookings."
                )
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Label("Add another staff member", systemImage: "checkmark")
                    Label("Set their availability", systemImage: "checkmark")
                    Label("Accept more bookings", systemImage: "checkmark")
                }
                .font(.subheadline)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    onUnlock()
                    dismiss()
                } label: {
                    Text("Unlock staff slot")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button("Not now") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

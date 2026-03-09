import SwiftUI

struct StaffUnlockTile: View {

    let businessId: String
    let staffCount: Int
    let allowed: Int
    let canAdd: Bool
    let onUnlockTapped: () -> Void
    let onManageTapped: () -> Void   // NEW

    var body: some View {

        VStack(spacing: 12) {

            Button {
                onManageTapped()
            } label: {

                HStack {
                    Image(systemName: "person.2.badge.plus")
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text("Staff Capacity")
                            .font(.headline)

                        Text("\(staffCount) of \(allowed) used")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if !canAdd {
                Button {
                    onUnlockTapped()
                } label: {
                    Text("Unlock more staff (£4.99/month)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

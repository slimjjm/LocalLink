import SwiftUI

struct BlockConflictSheet: View {

    let conflicts: [BookingConflict]
    let onCancelBlock: () -> Void
    let onEditBlock: () -> Void
    let onContinue: () -> Void

    var body: some View {

        NavigationStack {

            VStack(spacing: 20) {

                Text("This block overlaps \(conflicts.count) confirmed booking(s).")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                List(conflicts) { conflict in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conflict.customerName)
                            .font(.headline)

                        Text(conflict.serviceName)
                            .font(.subheadline)

                        Text("\(conflict.startDate.formatted())")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(spacing: 12) {

                    Button("Cancel Block") {
                        onCancelBlock()
                    }
                    .buttonStyle(.bordered)

                    Button("Edit Block") {
                        onEditBlock()
                    }
                    .buttonStyle(.bordered)

                    Button("Continue") {
                        onContinue()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .padding()
        }
    }
}

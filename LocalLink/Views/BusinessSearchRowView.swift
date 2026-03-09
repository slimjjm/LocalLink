import SwiftUI

struct BusinessSearchRowView: View {

    let business: Business

    @State private var nextSlot: Date?
    @State private var isPressed = false

    private let slotService = NextAvailableSlotService()

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            // MARK: Business name
            Text(business.businessName)
                .font(.headline)
                .foregroundColor(AppColors.charcoal)

            // MARK: Category + Town row

            HStack(spacing: 8) {

                // Category badge
                Text(business.category)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.primary.opacity(0.15))
                    )
                    .foregroundColor(AppColors.primary)

                Spacer()

                HStack(spacing: 4) {

                    Image(systemName: "mappin.and.ellipse")

                    Text(business.town)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Divider()

            // MARK: Availability

            if let nextSlot {

                VStack(alignment: .leading, spacing: 4) {

                    Text("Next available")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(
                        nextSlot.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.subheadline.bold())
                    .foregroundColor(AppColors.charcoal)
                }

                Button {

                    // quick book action

                } label: {

                    Text("Book \(nextSlot.formatted(date: .omitted, time: .shortened))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

            } else {

                HStack {

                    ProgressView()

                    Text("Checking availability…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)

        // MARK: Card styling

        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 8,
                    y: 3
                )
        )

        // MARK: Tap feedback animation

        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: isPressed)

        .contentShape(Rectangle())

        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )

        .onAppear {
            loadNextSlot()
        }
    }

    // MARK: Load availability

    private func loadNextSlot() {

        slotService.fetchNextSlot(
            businessId: business.id ?? ""
        ) { slot in

            DispatchQueue.main.async {
                self.nextSlot = slot
            }
        }
    }
}

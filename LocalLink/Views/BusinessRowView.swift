import SwiftUI

struct BusinessRowView: View {

    let business: Business

    @State private var nextSlot: Date?

    private let slotService = NextAvailableSlotService()

    var body: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(business.businessName)
                .font(.headline)
                .foregroundColor(AppColors.charcoal)

            Text("\(business.category) • \(business.town)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let nextSlot {

                if Calendar.current.isDateInToday(nextSlot) {

                    Text("Available today")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .onAppear {
            loadNextSlot()
        }
    }

    private func loadNextSlot() {

        guard let id = business.id else { return }

        slotService.fetchNextSlot(businessId: id) { slot in

            DispatchQueue.main.async {

                self.nextSlot = slot
            }
        }
    }
}

import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct CustomerBusinessProfileView: View {

    let businessId: String

    @State private var business: Business?
    @State private var nextSlot: Date?
    @State private var isLoading = true

    private let db = Firestore.firestore()
    private let slotService = NextAvailableSlotService()

    var body: some View {

        ScrollView {

            if isLoading {

                ProgressView("Loading business…")
                    .padding()

            }
            else if let business {

                VStack(alignment: .leading, spacing: 20) {

                    header(business)

                    availabilitySection

                    servicesCTA

                }
                .padding()
            }
        }
        .background(AppColors.background)
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {

            loadBusiness()
            loadNextSlot()
        }
    }

    // MARK: Header

    private func header(_ business: Business) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text(business.businessName)
                .font(.title.bold())
                .foregroundColor(AppColors.charcoal)

            Text("\(business.category) • \(business.town)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let address = business.address, !address.isEmpty {

                Label(address, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if business.isMobile {

                Text("Mobile business")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(AppColors.primary.opacity(0.15))
                    )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: Availability

    private var availabilitySection: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Availability")
                .font(.headline)

            if let nextSlot {

                if Calendar.current.isDateInToday(nextSlot) {

                    Text("Available today")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                Text(
                    nextSlot.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
                .font(.headline)

            } else {

                ProgressView("Checking availability…")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: Services CTA

    private var servicesCTA: some View {

        NavigationLink {

            CustomerServiceListView(
                businessId: businessId
            )

        } label: {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text("View services")
                        .font(.headline)

                    Text("See prices and book instantly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    // MARK: Firestore

    private func loadBusiness() {

        db.collection("businesses")
            .document(businessId)
            .getDocument { snap, _ in

                guard let snap else { return }

                business = try? snap.data(as: Business.self)
                isLoading = false
            }
    }

    private func loadNextSlot() {

        slotService.fetchNextSlot(businessId: businessId) { slot in

            DispatchQueue.main.async {
                nextSlot = slot
            }
        }
    }
}

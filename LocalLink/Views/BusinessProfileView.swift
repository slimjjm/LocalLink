import SwiftUI
import FirebaseAuth

struct BusinessProfileView: View {
    
    let business: Business
    let services: [BusinessService]
    let nextSlot: Date?
    
    private var isOwner: Bool {
        business.ownerId == Auth.auth().currentUser?.uid
    }

    var body: some View {

        ScrollView {
            VStack(spacing: 18) {

                headerSection

                if !isOwner {
                    contactButton
                }

                infoRow
                ratingSection

                if let bio = business.bio,
                   !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bioSection(bio)
                }

                availabilitySection
                servicesSection
            }
            .padding(16)
        }
        .background(AppColors.background)
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - HEADER

private extension BusinessProfileView {

    var headerSection: some View {

        ZStack(alignment: .bottomLeading) {

            if let photos = business.photoURLs, !photos.isEmpty {

                TabView {
                    ForEach(photos, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    }
                }
                .frame(height: 240)
                .tabViewStyle(.page)

            } else {

                LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {

                Text(business.businessName)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(business.town)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - CONTACT

private extension BusinessProfileView {

    var contactButton: some View {

        NavigationLink {
            EnquiryChatView(business: business)
        } label: {
            HStack {
                Image(systemName: "questionmark.bubble.fill")
                Text("Ask a question")
                Spacer()
            }
            .padding()
            .background(AppColors.primary.opacity(0.12))
            .foregroundColor(AppColors.primary)
            .cornerRadius(14)
        }
    }
}

// MARK: - INFO

private extension BusinessProfileView {

    var infoRow: some View {
        HStack {
            Text("\(business.category) • \(business.town)")
                .foregroundColor(.secondary)
            Spacer()
        }
        .modifier(CardStyle())
    }
}

// MARK: - RATING

private extension BusinessProfileView {

    var ratingSection: some View {
        HStack(spacing: 8) {

            Image(systemName: "star.fill")
                .foregroundColor(.yellow)

            Text("New")
                .font(.subheadline.weight(.semibold))

            Spacer()
        }
        .modifier(CardStyle())
    }
}

// MARK: - BIO

private extension BusinessProfileView {

    func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("About").font(.headline)
            Text(bio).foregroundColor(.secondary)
        }
        .modifier(CardStyle())
    }
}

// MARK: - AVAILABILITY

private extension BusinessProfileView {

    var availabilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Next availability")
                .font(.headline)

            if let nextSlot {
                Text(nextSlot.formatted(date: .abbreviated, time: .shortened))
                    .font(.title3.bold())
            } else {
                Text("No availability")
                    .foregroundColor(.secondary)
            }
        }
        .modifier(CardStyle())
    }
}

// MARK: - SERVICES

private extension BusinessProfileView {

    var servicesSection: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Services")
                .font(.headline)

            ForEach(services) { service in
                serviceCard(service)
            }
        }
    }

    func serviceCard(_ service: BusinessService) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(service.name)
                .font(.headline)

            Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")
                .foregroundColor(.secondary)

            if !isOwner, let businessId = business.id {

                NavigationLink {
                    BookingDateSelectorView(
                        businessId: businessId,
                        service: service,
                        customerAddress: nil
                    )
                } label: {
                    Text("Book now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.primary)
            }
        }
        .modifier(CardStyle())
    }
}

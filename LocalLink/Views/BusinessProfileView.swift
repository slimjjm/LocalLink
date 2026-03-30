import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct BusinessProfileView: View {
    
    let business: Business
    let services: [BusinessService]
    let nextSlot: Date?
    
    private var isOwner: Bool {
        business.ownerId == Auth.auth().currentUser?.uid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                headerSection
                
                if !isOwner {
                    contactButton
                }
                
                businessInfoSection
                ratingSection
                
                if let bio = business.bio,
                   !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bioSection(bio)
                }
        
                availabilitySection
                servicesSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact

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
            .background(AppColors.primary.opacity(0.15))
            .foregroundColor(AppColors.primary)
            .cornerRadius(14)
        }
    }
}

// MARK: - Header

private extension BusinessProfileView {
    
    var headerSection: some View {
        
        ZStack(alignment: .bottomLeading) {
            
            if let photos = business.photoURLs, !photos.isEmpty {
                
                TabView {
                    ForEach(photos, id: \.self) { urlString in
                        AsyncImage(url: URL(string: urlString)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 240)
                                .clipped()
                        } placeholder: {
                            ZStack {
                                Color(.secondarySystemBackground)
                                ProgressView().tint(AppColors.primary)
                            }
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
                .frame(height: 240)
            }
            
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.6)],
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
            .padding(16)
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Info

private extension BusinessProfileView {
    
    var businessInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(business.category) • \(business.town)")
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Rating

private extension BusinessProfileView {
    
    var ratingSection: some View {
        
        VStack(alignment: .leading, spacing: 10) {
            Text("Rating")
                .font(.headline)
            
            Text("New to LocalLink")
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Bio

private extension BusinessProfileView {
    
    func bioSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)
            Text(bio)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Availability

private extension BusinessProfileView {
    
    var availabilitySection: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text("Availability")
                .font(.headline)
            
            if let nextSlot {
                
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text("Next available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(nextSlot.formatted(date: .abbreviated, time: .shortened))
                        .font(.title3.bold())
                    
                    if Calendar.current.isDateInToday(nextSlot) {
                        Text("Available today")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.success.opacity(0.15))
                            .foregroundColor(AppColors.success)
                            .clipShape(Capsule())
                    }
                }
                
            } else {
                Text("No availability")
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Services

private extension BusinessProfileView {
    
    var servicesSection: some View {
        
        VStack(alignment: .leading, spacing: 14) {
            
            Text("Services")
                .font(.headline)
            
            if services.isEmpty {
                
                Text("No services available")
                    .foregroundColor(.secondary)
                
            } else {
                
                ForEach(services) { service in
                    serviceCard(service)
                }
            }
        }
    }
    
    func serviceCard(_ service: BusinessService) -> some View {
        
        VStack(alignment: .leading, spacing: 10) {
            
            Text(service.name)
                .font(.headline)
            
            Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")
                .foregroundColor(.secondary)
            
            if isOwner {
                
                Text("You can't book your own business")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            } else if let businessId = business.id,
                      let serviceId = service.id {
                
                NavigationLink {
                    BookingDateSelectorView(
                        businessId: businessId,
                        service: service,              // ✅ FIXED
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
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

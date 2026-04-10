import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessProfileView: View {
    
    let business: Business
    let nextSlot: Date?
    
    @State private var refreshedBusiness: Business?
    @State private var loadedServices: [BusinessService] = []
    
    // ✅ NEW: availability state
    @State private var fetchedNextSlot: Date?
    @State private var isLoadingAvailability = false
    
    private var currentBusiness: Business {
        refreshedBusiness ?? business
    }
    
    private var isOwner: Bool {
        currentBusiness.ownerId == Auth.auth().currentUser?.uid
    }
    
    // ✅ NEW: unified slot source
    private var resolvedNextSlot: Date? {
        nextSlot ?? fetchedNextSlot
    }
    
    var body: some View {

        print("👀 BusinessProfileView BODY CALLED")

        return ScrollView {
            VStack(spacing: 18) {
                
                headerSection
                
                if !isOwner {
                    contactButton
                }
                
                infoRow
                ratingSection
                
                if let bio = currentBusiness.bio,
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
        .task {
            print("🚀 TASK RUNNING")
            print("📌 business.id:", currentBusiness.id ?? "nil")
            
            loadBusiness()
            loadServices()
            loadAvailability() // ✅ ADDED
        }
        .onChange(of: currentBusiness.id) { _ in
            loadServices()
            loadAvailability() // ✅ ADDED
        }
    }
}

// MARK: - FIRESTORE

private extension BusinessProfileView {
    
    func loadBusiness() {
        guard let id = business.id else { return }
        
        Firestore.firestore()
            .collection("businesses")
            .document(id)
            .getDocument { snapshot, _ in
                
                guard let data = snapshot?.data() else { return }
                
                do {
                    let updated = try Firestore.Decoder().decode(Business.self, from: data)
                    self.refreshedBusiness = updated
                } catch {
                    print("❌ Decode failed:", error)
                }
            }
    }
    
    func loadServices() {
        
        guard let businessId = currentBusiness.id else {
            print("❌ No businessId for services")
            return
        }
        
        print("🔥 LOADING SERVICES FOR BUSINESS ID:", businessId)
        print("📂 PATH: businesses/\(businessId)/services")
        
        Firestore.firestore()
            .collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snapshot, error in
                
                if let error {
                    print("❌ Failed to load services:", error.localizedDescription)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("❌ No documents found (snapshot nil)")
                    self.loadedServices = []
                    return
                }
                
                print("📊 Documents fetched:", documents.count)
                
                if documents.isEmpty {
                    print("⚠️ Services collection is EMPTY at this path")
                }
                
                let services: [BusinessService] = documents.compactMap { doc in
                    
                    print("📦 RAW DOC ID:", doc.documentID)
                    print("📦 RAW DATA:", doc.data())
                    
                    do {
                        let service = try doc.data(as: BusinessService.self)
                        print("✅ Decoded service:", service.name)
                        return service
                    } catch {
                        print("❌ Decode error:", error)
                        print("❌ Problem doc:", doc.data())
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self.loadedServices = services
                }
                
                print("✅ FINAL services loaded:", services.count)
            }
    }
    
    // ✅ FIXED: availability loader (handles Int + Bool + filtering)
    
    func loadAvailability() {
        
        guard let businessId = currentBusiness.id else {
            print("❌ No businessId for availability")
            return
        }
        
        // Do not override a passed-in slot
        if nextSlot != nil {
            print("✅ Using passed nextSlot, skipping fetch")
            return
        }
        
        isLoadingAvailability = true
        
        let now = Date()
        let minimumNoticeHours: Double = 2
        let earliestBookableDate = now.addingTimeInterval(minimumNoticeHours * 3600)
        
        print("🔥 LOADING AVAILABILITY FOR:", businessId)
        print("⏱ Earliest bookable date:", earliestBookableDate)
        
        Firestore.firestore()
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .getDocuments { staffSnapshot, error in
                
                if let error {
                    print("❌ Staff fetch error:", error.localizedDescription)
                    DispatchQueue.main.async {
                        self.isLoadingAvailability = false
                    }
                    return
                }
                
                guard let staffDocs = staffSnapshot?.documents else {
                    print("⚠️ No staff found")
                    DispatchQueue.main.async {
                        self.isLoadingAvailability = false
                        self.fetchedNextSlot = nil
                    }
                    return
                }
                
                var allSlots: [QueryDocumentSnapshot] = []
                let group = DispatchGroup()
                
                for staff in staffDocs {
                    
                    group.enter()
                    
                    Firestore.firestore()
                        .collection("businesses")
                        .document(businessId)
                        .collection("staff")
                        .document(staff.documentID)
                        .collection("availableSlots")
                        .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: earliestBookableDate))
                        .order(by: "startTime")
                        .limit(to: 10)
                        .getDocuments { snapshot, error in
                            
                            if let error {
                                print("❌ Slot fetch error for staff \(staff.documentID):", error.localizedDescription)
                            }
                            
                            if let docs = snapshot?.documents {
                                allSlots.append(contentsOf: docs)
                            }
                            
                            group.leave()
                        }
                }
                
                group.notify(queue: .main) {
                    
                    self.isLoadingAvailability = false
                    
                    print("📊 Total slots fetched:", allSlots.count)
                    
                    let validDates: [Date] = allSlots.compactMap { doc in
                        let data = doc.data()
                        
                        let isBooked: Bool = {
                            if let b = data["isBooked"] as? Bool { return b }
                            if let i = data["isBooked"] as? Int { return i != 0 }
                            return false
                        }()
                        
                        guard isBooked == false else { return nil }
                        
                        guard let ts = data["startTime"] as? Timestamp else { return nil }
                        
                        let slotDate = ts.dateValue()
                        
                        guard slotDate >= earliestBookableDate else { return nil }
                        
                        return slotDate
                    }
                        .sorted()
                    
                    guard let firstValid = validDates.first else {
                        print("⚠️ No valid available slots found")
                        self.fetchedNextSlot = nil
                        return
                    }
                    
                    print("✅ Next slot found:", firstValid)
                    self.fetchedNextSlot = firstValid
                }
            }
    }
}
    // MARK: - HEADER
    
    private extension BusinessProfileView {
        
        var headerSection: some View {
            
            let photos = currentBusiness.photoURLs ?? []
            
            return ZStack(alignment: .bottomLeading) {
                
                if !photos.isEmpty {
                    
                    TabView {
                        ForEach(photos, id: \.self) { urlString in
                            
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    ZStack {
                                        Color(.secondarySystemBackground)
                                        ProgressView()
                                    }
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
                }
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text(currentBusiness.businessName)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text(currentBusiness.town)
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
            
            Group {
                
                if let businessId = currentBusiness.id,
                   let customerId = Auth.auth().currentUser?.uid {
                    
                    NavigationLink {
                        EnquiryChatView(
                            businessId: businessId,
                            customerId: customerId
                        )
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
                    
                } else {
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - INFO
    
    private extension BusinessProfileView {
        
        var infoRow: some View {
            HStack {
                Text("\(currentBusiness.category) • \(currentBusiness.town)")
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
                Text("About")
                    .font(.headline)
                Text(bio)
                    .foregroundColor(.secondary)
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
                
                if isLoadingAvailability {
                    
                    ProgressView()
                    
                } else if let next = resolvedNextSlot {
                    
                    Text(next.formatted(date: .abbreviated, time: .shortened))
                        .font(.title3.bold())
                    
                } else {
                    
                    Text("No bookable slots in the next 2 hours or later")
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
                
                if loadedServices.isEmpty {
                    Text("No services available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(loadedServices) { service in
                        serviceCard(service)
                    }
                }
            }
        }
        
        func serviceCard(_ service: BusinessService) -> some View {
            
            guard let businessId = currentBusiness.id else {
                return AnyView(EmptyView())
            }
            
            return AnyView(
                NavigationLink {
                    BookingDateSelectorView(
                        businessId: businessId,
                        service: service,
                        customerAddress: nil
                    )
                } label: {
                    
                    VStack(alignment: .leading, spacing: 10) {
                        
                        Text(service.name)
                            .font(.headline)
                        
                        Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")
                            .foregroundColor(.secondary)
                        
                        Text("Book now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.primary)
                            .cornerRadius(10)
                    }
                    .modifier(CardStyle())
                }
            )
        }
    }


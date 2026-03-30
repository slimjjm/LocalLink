import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift


struct SlotFilterEngine {
    
    static func validStartTimes(
        slotToStaff: [Date: [(slotId: String, staff: Staff)]],
        durationMinutes: Int
    ) -> [Date] {
        
        let sorted = slotToStaff.keys.sorted()
        let requiredSlots = durationMinutes / 30
        
        guard requiredSlots > 0 else { return [] }
        
        var valid: [Date] = []
        
        for i in 0..<sorted.count {
            
            var isValid = true
            
            for j in 0..<requiredSlots {
                
                let index = i + j
                
                if index >= sorted.count {
                    isValid = false
                    break
                }
                
                let current = sorted[index]
                
                // must exist
                guard slotToStaff[current] != nil else {
                    isValid = false
                    break
                }
                
                // must be continuous
                if j > 0 {
                    let prev = sorted[index - 1]
                    let expected = prev.addingTimeInterval(60 * 30)
                    
                    if current != expected {
                        isValid = false
                        break
                    }
                }
            }
            
            if isValid {
                valid.append(sorted[i])
            }
        }
        
        return valid
    }
}


struct TimeSlotSelectorView: View {
    
    let businessId: String
    let service: BusinessService
    let date: Date
    let customerAddress: String?
    
    @EnvironmentObject private var nav: NavigationState
    
    @State private var slotToStaff: [Date: [(slotId: String, staff: Staff)]] = [:]
    @State private var isLoading = true
    @State private var selectedSlot: Date?
    
    private let db = Firestore.firestore()
    
    var body: some View {
        
        VStack(spacing: 20) {
            
            Text("Choose a time")
                .font(.largeTitle.bold())
                .foregroundColor(AppColors.charcoal)
            
            if isLoading {
                
                ProgressView("Loading availability…")
                
            } else if slotToStaff.isEmpty {
                
                ContentUnavailableView(
                    "Fully booked",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No slots left on this date.")
                )
                
            } else {
                
                List(sortedSlots, id: \.self) { slot in
                    
                    Button {
                        selectedSlot = slot
                    } label: {
                        
                        HStack {
                            
                            Text(slot.formatted(date: .omitted, time: .shortened))
                                .font(.headline)
                                .foregroundColor(AppColors.charcoal)
                            
                            Spacer()
                            
                            Text("\(slotToStaff[slot]?.count ?? 0) available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if selectedSlot == slot {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            if let selectedSlot,
               let slotOptions = slotToStaff[selectedSlot],
               let chosen = slotOptions.first,
               let serviceId = service.id,
               let staffId = chosen.staff.id {
                
                Button {
                    nav.path.append(
                        .bookingSummary(
                            businessId: businessId,
                            serviceId: serviceId,
                            staffId: staffId,
                            slotId: chosen.slotId,
                            date: date,
                            time: selectedSlot,
                            customerAddress: customerAddress
                        )
                    )
                } label: {
                    Text("Book \(selectedSlot.formatted(date: .omitted, time: .shortened))")
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
            }
            
            Spacer()
        }
        .padding()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Time")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSlots()
        }
    }
    
    private var sortedSlots: [Date] {
        SlotFilterEngine.validStartTimes(
            slotToStaff: slotToStaff,
            durationMinutes: service.durationMinutes
        )
    }
    
    // MARK: - Load PRE-GENERATED SAFE SLOTS ONLY
    
    private func loadSlots() {
        
        isLoading = true
        selectedSlot = nil
        slotToStaff = [:]
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                
                if let error {
                    print("❌ Failed loading staff: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                let staffList = snapshot?.documents.compactMap {
                    try? $0.data(as: Staff.self)
                } ?? []
                
                let eligibleStaff = staffList.filter { staff in
                    guard let serviceId = service.id else { return false }
                    let serviceIds = staff.serviceIds ?? []
                    return serviceIds.contains(serviceId)
                }
                
                if eligibleStaff.isEmpty {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                let group = DispatchGroup()
                
                for staff in eligibleStaff {
                    
                    guard let staffId = staff.id else { continue }
                    group.enter()
                    
                    self.db
                        .collection("businesses")
                        .document(self.businessId)
                        .collection("staff")
                        .document(staffId)
                        .collection("availableSlots")
                        .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                        .whereField("startTime", isLessThan: Timestamp(date: endOfDay))
                        .whereField("isBooked", isEqualTo: false)
                        .getDocuments { snapshot, error in
                            
                            defer { group.leave() }
                            
                            if let error {
                                print("❌ Failed loading slots for staff \(staffId): \(error.localizedDescription)")
                                return
                            }
                            
                            let slots = snapshot?.documents.compactMap { doc -> (slotId: String, slotDate: Date)? in
                                guard let ts = doc["startTime"] as? Timestamp else { return nil }
                                return (slotId: doc.documentID, slotDate: ts.dateValue())
                            } ?? []
                            
                            DispatchQueue.main.async {
                                for slot in slots {
                                    self.slotToStaff[slot.slotDate, default: []].append((slotId: slot.slotId, staff: staff))
                                }
                            }
                        }
                }
                
                group.notify(queue: .main) {
                    self.isLoading = false
                }
            }
    }
}

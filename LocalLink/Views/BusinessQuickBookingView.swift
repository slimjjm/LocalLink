import SwiftUI
import FirebaseAuth
import MapKit

struct BusinessQuickBookingView: View {
    
    let businessId: String
    let staffId: String
    let startTime: Date
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var customerName = ""
    @State private var customerAddress = ""
    
    @StateObject private var addressSearch = AddressSearchService()
    
    @State private var services: [BusinessService] = []
    @State private var selectedServiceId: String?
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    @State private var repeatBooking = false
    @State private var repeatFrequency: RepeatFrequency = .weekly
    @State private var repeatCount: Int = 2
    
    private let bookingService = BookingService()
    private let serviceRepo = BusinessServiceRepository()
    
    var body: some View {
        
        NavigationStack {
            
            Form {
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Customer details") {
                    
                    TextField("Customer name", text: $customerName)
                    
                    TextField("Search address", text: $addressSearch.query)
                        .onChange(of: addressSearch.query) { newValue in
                            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                customerAddress = ""
                            }
                        }
                    
                    if !addressSearch.results.isEmpty {
                        ForEach(addressSearch.results, id: \.self) { result in
                            Button {
                                let fullAddress = [result.title, result.subtitle]
                                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                                    .joined(separator: ", ")
                                
                                customerAddress = fullAddress
                                addressSearch.query = fullAddress
                                addressSearch.clearResults()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .foregroundColor(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !customerAddress.isEmpty {
                        Text("Selected address: \(customerAddress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Service") {
                    if services.isEmpty {
                        Text("No services yet")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Service", selection: $selectedServiceId) {
                            ForEach(services) { service in
                                Text("\(service.name) • \(DurationFormatter.text(from: service.durationMinutes))")
                                    .tag(service.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section("Time") {
                    if let service = selectedService {
                        Text(
                            "\(startTime.formatted(date: .abbreviated, time: .shortened)) → \(calculatedEndTime(for: startTime, service: service).formatted(date: .omitted, time: .shortened))"
                        )
                        .foregroundColor(.secondary)
                        
                        Text("Duration: \(DurationFormatter.text(from: service.durationMinutes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select a service")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Repeat") {
                    Toggle("Repeat booking", isOn: $repeatBooking)
                    
                    if repeatBooking {
                        Picker("Frequency", selection: $repeatFrequency) {
                            ForEach(RepeatFrequency.allCases) { frequency in
                                Text(frequency.title).tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Stepper("Occurrences: \(repeatCount)", value: $repeatCount, in: 2...12)
                        
                        Text(repeatSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button {
                        createBookings()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text(repeatBooking ? "Create bookings" : "Create booking")
                        }
                    }
                    .disabled(
                        isSaving ||
                        selectedService == nil ||
                        customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        Auth.auth().currentUser?.uid == nil
                    )
                }
            }
            .navigationTitle("New booking")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadServices()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var selectedService: BusinessService? {
        guard let selectedServiceId else { return nil }
        return services.first(where: { $0.id == selectedServiceId })
    }
    
    private var repeatSummary: String {
        guard let service = selectedService else {
            return "Select a service to preview repeat bookings."
        }
        
        let dates = buildStartDates()
        let formatted = dates.prefix(3).map {
            $0.formatted(date: .abbreviated, time: .shortened)
        }
        
        if dates.count <= 3 {
            return "Will create \(dates.count) booking(s): \(formatted.joined(separator: " • "))"
        } else {
            return "Will create \(dates.count) booking(s): \(formatted.joined(separator: " • ")) • ..."
        }
    }
    
    private func calculatedEndTime(for start: Date, service: BusinessService) -> Date {
        Calendar.current.date(byAdding: .minute, value: service.durationMinutes, to: start) ?? start
    }
    
    private func buildStartDates() -> [Date] {
        guard repeatBooking else { return [startTime] }
        
        var dates: [Date] = []
        var current = startTime
        
        for _ in 0..<repeatCount {
            dates.append(current)
            
            switch repeatFrequency {
            case .weekly:
                current = Calendar.current.date(byAdding: .day, value: 7, to: current) ?? current
            case .fortnightly:
                current = Calendar.current.date(byAdding: .day, value: 14, to: current) ?? current
            case .monthly:
                current = Calendar.current.date(byAdding: .month, value: 1, to: current) ?? current
            }
        }
        
        return dates
    }
    
    // MARK: - Load
    
    private func loadServices() {
        serviceRepo.fetchServices(businessId: businessId) { fetched in
            DispatchQueue.main.async {
                self.services = fetched
                if self.selectedServiceId == nil {
                    self.selectedServiceId = fetched.first?.id
                }
            }
        }
    }
    
    // MARK: - Create
    
    private func createBookings() {
        
        errorMessage = nil
        
        guard let service = selectedService else {
            errorMessage = "Please select a service."
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            errorMessage = "User not authenticated."
            return
        }
        
        let trimmedName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = customerAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter a customer name."
            return
        }
        
        isSaving = true
        
        let dates = buildStartDates()
        createBookingSeries(
            dates: dates,
            index: 0,
            uid: uid,
            service: service,
            customerName: trimmedName,
            customerAddress: trimmedAddress
        )
    }
    
    private func createBookingSeries(
        dates: [Date],
        index: Int,
        uid: String,
        service: BusinessService,
        customerName: String,
        customerAddress: String
    ) {
        guard index < dates.count else {
            isSaving = false
            dismiss()
            return
        }
        
        let bookingStart = dates[index]
        
        bookingService.confirmBooking(
            businessId: businessId,
            customerId: uid,
            customerName: customerName,
            customerAddress: customerAddress,
            service: service,
            staffId: staffId,
            date: bookingStart,
            startTime: bookingStart,
            paymentIntentId: nil,
            source: "manual"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    createBookingSeries(
                        dates: dates,
                        index: index + 1,
                        uid: uid,
                        service: service,
                        customerName: customerName,
                        customerAddress: customerAddress
                    )
                    
                case .failure(let error):
                    isSaving = false
                    errorMessage = "Booking \(index + 1) failed: \(error.localizedDescription)"
                }
            }
        }
    }
}

enum RepeatFrequency: String, CaseIterable, Identifiable {
    case weekly
    case fortnightly
    case monthly
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .weekly:
            return "Weekly"
        case .fortnightly:
            return "Every 2 weeks"
        case .monthly:
            return "Monthly"
        }
    }
}

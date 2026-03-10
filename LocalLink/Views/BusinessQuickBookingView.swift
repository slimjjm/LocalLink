import SwiftUI

struct BusinessQuickBookingView: View {

    let businessId: String
    let staffId: String
    let startTime: Date
    let endTime: Date

    @Environment(\.dismiss) private var dismiss

    @State private var customerName = ""
    @State private var customerAddress = ""

    @State private var services: [BusinessService] = []
    @State private var selectedServiceId: String?

    @State private var isSaving = false
    @State private var errorMessage: String?

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

                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                    TextField("Address", text: $customerAddress)
                }

                Section("Staff") {
                    Text("Staff ID: \(staffId)")
                        .foregroundColor(.secondary)
                }

                Section("Service") {
                    if services.isEmpty {
                        Text("No services yet")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Service", selection: $selectedServiceId) {
                            ForEach(services) { service in
                                Text(service.name)
                                    .tag(service.id as String?)
                            }
                        }
                    }
                }

                Section("Time") {
                    Text(
                        "\(startTime.formatted(date: .abbreviated, time: .shortened)) → \(endTime.formatted(date: .omitted, time: .shortened))"
                    )
                    .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        createBooking()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create booking")
                        }
                    }
                    .disabled(
                        isSaving ||
                        services.isEmpty ||
                        selectedServiceId == nil ||
                        customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("New booking")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadServices() }
        }
    }

    private func loadServices() {
        serviceRepo.fetchServices(businessId: businessId) { fetched in
            DispatchQueue.main.async {
                self.services = fetched
                self.selectedServiceId = fetched.first?.id
            }
        }
    }

    private func createBooking() {

        errorMessage = nil

        guard let serviceId = selectedServiceId,
              let service = services.first(where: { $0.id == serviceId }) else {
            errorMessage = "Please select a service."
            return
        }

        guard !staffId.isEmpty else {
            errorMessage = "Missing staff id."
            return
        }

        isSaving = true

        bookingService.confirmBooking(
            businessId: businessId,
            customerId: "manual",
            customerName: customerName.trimmingCharacters(in: .whitespacesAndNewlines),
            customerAddress: customerAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            service: service,
            staffId: staffId,
            date: startTime,
            startTime: startTime,
            endTime: endTime,
            paymentIntentId: nil,
            source: "manual"
        ) { result in

            DispatchQueue.main.async {
                isSaving = false

                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

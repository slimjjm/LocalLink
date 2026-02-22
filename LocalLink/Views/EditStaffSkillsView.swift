import SwiftUI
import FirebaseFirestore

struct EditStaffSkillsView: View {

    let businessId: String
    let staffId: String

    @Environment(\.dismiss) private var dismiss

    @State private var allServices: [BusinessService] = []
    @State private var selectedServiceIds: Set<String> = []
    @State private var staffName: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let db = Firestore.firestore()

    var body: some View {
        List {

            Section("Staff") {
                Text(staffName)
                    .font(.headline)
            }

            Section("Skills") {
                ForEach(allServices) { service in
                    let id = service.id ?? ""

                    Button {
                        toggle(serviceId: id)
                    } label: {
                        HStack {
                            Text(service.name)
                            Spacer()
                            if selectedServiceIds.contains(id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .disabled(id.isEmpty)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        if isSaving { ProgressView() }
                        Text(isSaving ? "Saving…" : "Save Skills")
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Edit Skills")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStaff()
            loadServices()
        }
    }

    private func toggle(serviceId: String) {
        guard !serviceId.isEmpty else { return }
        if selectedServiceIds.contains(serviceId) {
            selectedServiceIds.remove(serviceId)
        } else {
            selectedServiceIds.insert(serviceId)
        }
    }

    private func loadStaff() {
        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .getDocument { snap, _ in

                if let data = snap?.data() {

                    let name = data["name"] as? String ?? "Staff"
                    let ids = data["serviceIds"] as? [String] ?? []

                    DispatchQueue.main.async {
                        self.staffName = name
                        self.selectedServiceIds = Set(ids)
                    }
                }
            }
    }

    private func loadServices() {
        db.collection("businesses")
            .document(businessId)
            .collection("services")
            .getDocuments { snap, error in

                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }

                let services: [BusinessService] =
                    snap?.documents.compactMap {
                        try? $0.data(as: BusinessService.self)
                    } ?? []

                DispatchQueue.main.async {
                    self.allServices = services
                }
            }
    }

    private func save() {

        guard !staffId.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        let ids = Array(selectedServiceIds)

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)
            .updateData([
                "serviceIds": ids
            ]) { error in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.dismiss()
                    }
                }
            }
    }
}

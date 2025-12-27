import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessServiceListView: View {

    let businessId: String

    @State private var services: [Service] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

    @State private var showAddService = false

    private let db = Firestore.firestore()

    // MARK: - Body
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Services")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showAddService = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddService) {
                    NavigationStack {
                        ServiceFormView(
                            businessId: businessId,
                            existingService: nil
                        )
                    }
                }
                .onAppear(perform: startListening)
                .onDisappear {
                    listener?.remove()
                    listener = nil
                }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {

        if isLoading {
            ProgressView("Loading services…")
        }

        else if let errorMessage {
            VStack(spacing: 12) {
                Text("Couldn’t load services")
                    .font(.headline)

                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }

        else if services.isEmpty {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "No services yet",
                    systemImage: "scissors",
                    description: Text("Add your first service to start taking bookings.")
                )

                Button("Add Service") {
                    showAddService = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }

        else {
            List {
                ForEach(services) { service in
                    NavigationLink {
                        ServiceFormView(
                            businessId: businessId,
                            existingService: service
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(service.name)
                                .font(.headline)

                            Text("£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins")

                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Firestore Listener
    private func startListening() {
        isLoading = true
        errorMessage = nil

        listener?.remove()

        listener = db.collection("businesses")
            .document(businessId)
            .collection("services")
            .order(by: "name")
            .addSnapshotListener { snapshot, error in

                if let error {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    return
                }

                services = snapshot?.documents.compactMap {
                    try? $0.data(as: Service.self)
                } ?? []

                isLoading = false
            }
    }
}

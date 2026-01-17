import SwiftUI
import FirebaseFirestore
import FirebaseFirestoreSwift

struct BusinessServiceListView: View {

    let businessId: String

    @State private var services: [BusinessService] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

    @State private var showAddService = false

    private let db = Firestore.firestore()

    var body: some View {
        Group {

            // Loading
            if isLoading {
                ProgressView("Loading services…")
            }

            // Error
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

            // Empty state
            else if services.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No services yet",
                        systemImage: "scissors",
                        description: Text(
                            "Add your first service to start taking bookings."
                        )
                    )

                    Button("Add Service") {
                        showAddService = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }

            // Services list
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

                                Text(
                                    "£\(service.price, specifier: "%.2f") • \(service.durationMinutes) mins"
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Services")

        // ✅ PLUS BUTTON NOW WORKS
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddService = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }

        // ✅ THIS WAS MISSING
        .navigationDestination(isPresented: $showAddService) {
            ServiceFormView(
                businessId: businessId,
                existingService: nil
            )
        }

        .onAppear {
            startListening()
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    // MARK: - Firestore Listener
    private func startListening() {
        isLoading = true
        errorMessage = nil

        listener?.remove()

        listener = db
            .collection("businesses")
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
                    try? $0.data(as: BusinessService.self)
                } ?? []

                isLoading = false
            }
    }
}


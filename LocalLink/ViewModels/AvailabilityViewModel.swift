import Foundation
import FirebaseFirestore

// MARK: - Models

struct EditableDay: Identifiable, Codable {
    let id = UUID()
    var day: String        // "monday"
    var start: String      // "09:00"
    var end: String        // "17:00"
    var closed: Bool
}

struct BusinessAvailability: Codable {
    var capacity: Int
    var slotInterval: Int
    var days: [String: EditableDay]
}

// MARK: - ViewModel

@MainActor
final class AvailabilityViewModel: ObservableObject {

    // UI-bound state
    @Published var days: [EditableDay] = []
    @Published var slotInterval: Int = 30
    @Published var capacity: Int = 1

    @Published var isLoading: Bool = true
    @Published var errorMessage: String = ""
    @Published var didSave: Bool = false

    // Firestore
    private let db = Firestore.firestore()
    private let businessId: String

    // Constants
    static let weekOrder: [String] = [
        "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday", "sunday"
    ]

    let allowedIntervals: [Int] = [15, 30, 45, 60]

    // MARK: - Init

    init(businessId: String) {
        self.businessId = businessId
        loadAvailability()
    }

    // MARK: - Load (Option A: business document field)

    func loadAvailability() {
        isLoading = true
        errorMessage = ""
        didSave = false

        db.collection("businesses")
            .document(businessId)
            .getDocument { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.errorMessage = error.localizedDescription
                    self.initializeDefaults()
                    return
                }

                guard
                    let data = snapshot?.data(),
                    let availabilityData = data["availability"] as? [String: Any]
                else {
                    self.initializeDefaults()
                    return
                }

                do {
                    let json = try JSONSerialization.data(withJSONObject: availabilityData)
                    let decoded = try JSONDecoder().decode(BusinessAvailability.self, from: json)

                    self.capacity = max(decoded.capacity, 1)
                    self.slotInterval = self.allowedIntervals.contains(decoded.slotInterval)
                        ? decoded.slotInterval
                        : 30

                    self.days = Self.weekOrder.compactMap {
                        decoded.days[$0]
                    }

                } catch {
                    self.errorMessage = "Failed to decode availability"
                    self.initializeDefaults()
                }
            }
    }

    // MARK: - Save (atomic overwrite)

    func saveAvailability() {
        errorMessage = ""
        didSave = false

        let availability = BusinessAvailability(
            capacity: max(capacity, 1),
            slotInterval: slotInterval,
            days: Dictionary(uniqueKeysWithValues: days.map { ($0.day, $0) })
        )

        do {
            let encoded = try JSONEncoder().encode(availability)
            let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]

            db.collection("businesses")
                .document(businessId)
                .updateData(["availability": dict]) { [weak self] error in
                    guard let self else { return }

                    if let error {
                        self.errorMessage = error.localizedDescription
                    } else {
                        self.didSave = true
                    }
                }

        } catch {
            self.errorMessage = "Failed to save availability"
        }
    }

    // MARK: - Helpers

    func availabilityFor(date: Date) -> EditableDay? {
        let weekday = Calendar.current.component(.weekday, from: date)
        let index = (weekday + 5) % 7   // Monday = 0
        return days.indices.contains(index) ? days[index] : nil
    }

    private func initializeDefaults() {
        days = Self.weekOrder.map {
            EditableDay(day: $0, start: "09:00", end: "17:00", closed: false)
        }
        capacity = max(capacity, 1)
        if !allowedIntervals.contains(slotInterval) {
            slotInterval = 30
        }
    }
}

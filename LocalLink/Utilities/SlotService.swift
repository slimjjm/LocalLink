import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class SlotService {

    private let db = Firestore.firestore()

    func loadSlots(
        businessId: String,
        selectedDate: Date,
        serviceDurationMinutes: Int,
        completion: @escaping ([TimeSlot]) -> Void
    ) {

        let weekday = selectedDate.weekdayString()

        db.collection("businesses")
            .document(businessId)
            .collection("staff")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { staffSnapshot, _ in

                guard let staffDocs = staffSnapshot?.documents else {
                    completion([])
                    return
                }

                var allSlots: [TimeSlot] = []
                let group = DispatchGroup()

                for staffDoc in staffDocs {
                    let staffId = staffDoc.documentID
                    let staffName = staffDoc["name"] as? String ?? "Staff"

                    group.enter()

                    self.db.collection("businesses")
                        .document(businessId)
                        .collection("staff")
                        .document(staffId)
                        .collection("availability")
                        .document(weekday)
                        .getDocument { availabilitySnap, _ in

                            defer { group.leave() }

                            guard
                                let data = availabilitySnap?.data(),
                                let isWorking = data["isWorking"] as? Bool,
                                isWorking,
                                let startStr = data["start"] as? String,
                                let endStr = data["end"] as? String,
                                let startDate = TimeParser.date(
                                    on: selectedDate,
                                    timeString: startStr
                                ),
                                let endDate = TimeParser.date(
                                    on: selectedDate,
                                    timeString: endStr
                                )
                            else {
                                return
                            }

                            let slots = SlotGenerator.generateSlots(
                                availabilityStart: startDate,
                                availabilityEnd: endDate,
                                slotMinutes: serviceDurationMinutes,
                                staffId: staffId,
                                staffName: staffName
                            )

                            allSlots.append(contentsOf: slots)
                        }
                }

                group.notify(queue: .main) {
                    completion(allSlots.sorted { $0.start < $1.start })
                }
            }
    }
}

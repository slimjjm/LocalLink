import Foundation
import FirebaseFirestore

struct SlotGenerator {

    private let db = Firestore.firestore()
    private let calendar = Calendar.current

    func generateSlotsForDay(
        businessId: String,
        staffId: String,
        date: Date,
        startTime: Date,
        endTime: Date
    ) async {

        let staffRef = db
            .collection("businesses")
            .document(businessId)
            .collection("staff")
            .document(staffId)

        let slots = SlotBuilder.buildSlots(
            date: date,
            startTime: startTime,
            endTime: endTime,
            intervalMinutes: 30
        )

        for slotStart in slots {

            let slotEnd = calendar.date(
                byAdding: .minute,
                value: 30,
                to: slotStart
            )!

            let slotId = ISO8601DateFormatter().string(from: slotStart)

            try? await staffRef
                .collection("availableSlots")
                .document(slotId)
                .setData([
                    "startTime": Timestamp(date: slotStart),
                    "endTime": Timestamp(date: slotEnd),
                    "date": Timestamp(date: date),
                    "isBooked": false
                ])
        }
    }
}

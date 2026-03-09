import Foundation
import FirebaseFirestore

enum SlotBatchWriter {

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func generate(
        batch: WriteBatch,
        staffRef: DocumentReference,
        businessId: String,
        staffId: String,
        start: Date,
        end: Date,
        intervalMinutes: Int = 30,
        timeBlocks: [TimeBlock] = []
    ) -> Int {

        var writes = 0
        var current = start
        let calendar = Calendar.current

        let slotCollection = staffRef.collection("availableSlots")

        while current < end {

            guard let slotEnd = calendar.date(byAdding: .minute, value: intervalMinutes, to: current) else {
                break
            }

            let overlaps = timeBlocks.contains { tb in
                current < tb.endDate && slotEnd > tb.startDate
            }

            if !overlaps {

                let slotId = isoFormatter.string(from: current)
                let ref = slotCollection.document(slotId)

                batch.setData([
                    "businessId": businessId,
                    "staffId": staffId,
                    "startTime": Timestamp(date: current),
                    "endTime": Timestamp(date: slotEnd),
                    "isBooked": false
                ], forDocument: ref, merge: true)

                writes += 1
            }

            current = slotEnd
        }

        return writes
    }
}

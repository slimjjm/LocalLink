import Foundation

struct SlotBuilder {

    static func buildSlots(
        date: Date,
        startTime: Date,
        endTime: Date,
        intervalMinutes: Int
    ) -> [Date] {

        guard intervalMinutes > 0 else { return [] }

        var slots: [Date] = []
        var cursor = startTime
        let interval = TimeInterval(intervalMinutes * 60)

        while cursor.addingTimeInterval(interval) <= endTime {
            slots.append(cursor)
            cursor = cursor.addingTimeInterval(interval)
        }

        return slots
    }
}

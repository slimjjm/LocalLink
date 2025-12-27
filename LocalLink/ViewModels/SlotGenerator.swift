import Foundation

struct SlotGenerator {

    /// Generates valid booking slots within opening hours
    /// - Parameters:
    ///   - date: The day being booked
    ///   - openTime: "HH:mm"
    ///   - closeTime: "HH:mm"
    ///   - slotInterval: minutes between slots (e.g. 15 / 30)
    ///   - serviceDuration: minutes required for service
    static func generateSlots(
        on date: Date,
        openTime: String,
        closeTime: String,
        slotInterval: Int,
        serviceDuration: Int
    ) -> [Date] {

        guard
            let openDate = date.atTime(openTime),
            let closeDate = date.atTime(closeTime),
            slotInterval > 0,
            serviceDuration > 0
        else {
            return []
        }

        var slots: [Date] = []
        var cursor = openDate

        while cursor.addingMinutes(serviceDuration) <= closeDate {
            slots.append(cursor)
            cursor = cursor.addingMinutes(slotInterval)
        }

        return slots
    }
}


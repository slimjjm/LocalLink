import Foundation

enum BookingDateBuilder {

    static func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current

        let dateParts = calendar.dateComponents([.year, .month, .day], from: date)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)

        var merged = DateComponents()
        merged.year = dateParts.year
        merged.month = dateParts.month
        merged.day = dateParts.day
        merged.hour = timeParts.hour
        merged.minute = timeParts.minute

        return calendar.date(from: merged) ?? date
    }

    static func endDate(start: Date, durationMinutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: start) ?? start
    }
}

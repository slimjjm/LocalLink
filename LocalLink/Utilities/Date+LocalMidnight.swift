import Foundation

extension Date {

    func localMidnight() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal.startOfDay(for: self)
    }
}

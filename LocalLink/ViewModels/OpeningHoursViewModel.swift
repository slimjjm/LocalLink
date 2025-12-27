import Foundation

class OpeningHoursViewModel: ObservableObject {

    @Published var hours = OpeningHours.defaultHours

    let days = [
        ("Monday", \OpeningHours.monday),
        ("Tuesday", \OpeningHours.tuesday),
        ("Wednesday", \OpeningHours.wednesday),
        ("Thursday", \OpeningHours.thursday),
        ("Friday", \OpeningHours.friday),
        ("Saturday", \OpeningHours.saturday),
        ("Sunday", \OpeningHours.sunday)
    ]
}

import Foundation

enum BusinessCategory: String, CaseIterable, Identifiable {
    case dogGroomer = "Dog Groomer"
    case hairSalon = "Hair Salon"
    case barber = "Barber"
    case nails = "Nails"
    case electrician = "Electrician"
    case plumber = "Plumber"
    case cleaner = "Cleaner"
    case gardener = "Gardener"

    var id: String { rawValue }
}

enum SupportedTown: String, CaseIterable, Identifiable {
    case burntwood = "Burntwood"
    case lichfield = "Lichfield"
    case cannock = "Cannock"
    case walsall = "Walsall"
    case tamworth = "Tamworth"
    case suttonColdfield = "Sutton Coldfield"

    var id: String { rawValue }
}

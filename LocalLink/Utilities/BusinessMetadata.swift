import Foundation

    enum BusinessCategory: String, CaseIterable, Identifiable {
        
        case cleaner = "Cleaner"
        case dogWalker = "Dog Walker"
        case personalTrainer = "Personal Trainer"
        
        case dogGroomer = "Dog Groomer"
        case hairSalon = "Hair Salon"
        case barber = "Barber"
        case nails = "Nails"
        
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

import Foundation

/// How a calendar day should read at a glance.
enum DayAvailability: Equatable, Sendable {
    case free
    case booked
    case tentative
    case nonWorking

    var title: String {
        switch self {
        case .free: String(localized: "Free", comment: "Day availability")
        case .booked: String(localized: "Booked", comment: "Day availability")
        case .tentative: String(localized: "Quoted", comment: "Day availability")
        case .nonWorking: String(localized: "Off", comment: "Non-working day")
        }
    }
}

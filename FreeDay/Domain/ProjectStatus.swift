import Foundation

/// Lifecycle of a job. Only booked work occupies availability.
enum ProjectStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case quoted
    case booked
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quoted: String(localized: "Quoted", comment: "Project status")
        case .booked: String(localized: "Booked", comment: "Project status")
        case .completed: String(localized: "Completed", comment: "Project status")
        }
    }
}

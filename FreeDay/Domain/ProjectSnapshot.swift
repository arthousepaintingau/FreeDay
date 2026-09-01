import Foundation

/// A value-type copy of a project used by the scheduling engine and tests.
/// Persistence lives in SwiftData; this type stays free of UI and storage.
struct ProjectSnapshot: Equatable, Identifiable, Sendable {
    var id: UUID
    var projectName: String
    var customerName: String
    var phoneNumber: String?
    var address: String?
    var notes: String?
    var status: ProjectStatus
    var startDate: Date?
    var durationInWorkingDays: Int
    var bufferInWorkingDays: Int = 0
    var createdDate: Date
    var completedDate: Date?

    /// Booked work with a start date occupies the calendar.
    var blocksAvailability: Bool {
        status == .booked && startDate != nil && durationInWorkingDays > 0
    }

    /// Quoted work with a start date is visible as tentative, but never blocks a slot.
    var showsAsTentative: Bool {
        status == .quoted && startDate != nil && durationInWorkingDays > 0
    }

    /// Only booked work with a start date can be moved through Reschedule.
    var canReschedule: Bool {
        status == .booked && startDate != nil && durationInWorkingDays > 0
    }
}

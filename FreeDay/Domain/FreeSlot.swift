import Foundation

/// A run of consecutive working days that is free to book.
struct FreeSlot: Equatable, Identifiable, Sendable {
    var start: Date
    var end: Date
    var workingDates: [Date]

    var id: Date { start }

    var durationWorkingDays: Int { workingDates.count }
}

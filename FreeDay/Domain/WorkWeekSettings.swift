import Foundation

/// Describes which weekdays count as working days.
/// Country, timezone, and weekend rules live here so the engine stays generic.
struct WorkWeekSettings: Equatable, Sendable, Codable {
    /// `Calendar` weekday values. Gregorian: Sunday = 1 … Saturday = 7.
    var workingWeekdays: Set<Int>
    var timeZoneIdentifier: String
    var localeIdentifier: String
    /// `Calendar.firstWeekday`. Monday = 2 in Gregorian.
    var firstWeekday: Int

    static let australiaDefault = WorkWeekSettings(
        workingWeekdays: [2, 3, 4, 5, 6],
        timeZoneIdentifier: "Australia/Sydney",
        localeIdentifier: "en_AU",
        firstWeekday: 2
    )
}

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

    static let sundayWeekday = 1
    static let saturdayWeekday = 7
    /// Monday through Friday. These stay on so the week cannot be emptied.
    static let mondayThroughFriday: Set<Int> = [2, 3, 4, 5, 6]

    static let australiaDefault = australia()

    var worksSaturday: Bool { workingWeekdays.contains(Self.saturdayWeekday) }
    var worksSunday: Bool { workingWeekdays.contains(Self.sundayWeekday) }

    func isWorkingWeekday(_ weekday: Int) -> Bool {
        workingWeekdays.contains(weekday)
    }

    /// Australia default week with optional weekend working days.
    /// Monday–Friday are always included.
    static func australia(worksSaturday: Bool = false, worksSunday: Bool = false) -> WorkWeekSettings {
        var days = mondayThroughFriday
        if worksSaturday { days.insert(saturdayWeekday) }
        if worksSunday { days.insert(sundayWeekday) }
        return WorkWeekSettings(
            workingWeekdays: days,
            timeZoneIdentifier: "Australia/Sydney",
            localeIdentifier: "en_AU",
            firstWeekday: 2
        )
    }
}

/// Ordered weekdays for settings UI. Raw values match `Calendar` weekday numbers.
enum WorkWeekday: Int, CaseIterable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    static let mondayFirst: [WorkWeekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var isConfigurable: Bool {
        self == .saturday || self == .sunday
    }

    var name: String {
        switch self {
        case .monday: String(localized: "Monday", comment: "Working day name")
        case .tuesday: String(localized: "Tuesday", comment: "Working day name")
        case .wednesday: String(localized: "Wednesday", comment: "Working day name")
        case .thursday: String(localized: "Thursday", comment: "Working day name")
        case .friday: String(localized: "Friday", comment: "Working day name")
        case .saturday: String(localized: "Saturday", comment: "Working day name")
        case .sunday: String(localized: "Sunday", comment: "Working day name")
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .monday: "settings-work-monday"
        case .tuesday: "settings-work-tuesday"
        case .wednesday: "settings-work-wednesday"
        case .thursday: "settings-work-thursday"
        case .friday: "settings-work-friday"
        case .saturday: "settings-work-saturday"
        case .sunday: "settings-work-sunday"
        }
    }
}

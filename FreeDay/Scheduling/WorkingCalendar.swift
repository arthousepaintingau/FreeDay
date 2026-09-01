import Foundation

/// Calendar math for working days. No holidays yet — only weekday rules.
struct WorkingCalendar: Sendable, Equatable {
    var settings: WorkWeekSettings
    var calendar: Calendar

    init(settings: WorkWeekSettings) {
        self.settings = settings
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: settings.localeIdentifier)
        calendar.timeZone = TimeZone(identifier: settings.timeZoneIdentifier)
            ?? .gmt
        calendar.firstWeekday = settings.firstWeekday
        self.calendar = calendar
    }

    static let australiaDefault = WorkingCalendar(settings: .australiaDefault)

    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func isWorkingDay(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return settings.workingWeekdays.contains(weekday)
    }

    func nextWorkingDay(onOrAfter date: Date) -> Date {
        var cursor = startOfDay(date)
        while !isWorkingDay(cursor) {
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                return cursor
            }
            cursor = next
        }
        return cursor
    }

    func nextWorkingDay(after date: Date) -> Date {
        let dayAfter = calendar.date(byAdding: .day, value: 1, to: startOfDay(date)) ?? date
        return nextWorkingDay(onOrAfter: dayAfter)
    }

    /// Returns `count` working days, starting at `start` or the next working day if `start` is off.
    func workingDays(startingAt start: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        var dates: [Date] = []
        dates.reserveCapacity(count)
        var cursor = nextWorkingDay(onOrAfter: start)
        dates.append(cursor)
        while dates.count < count {
            cursor = nextWorkingDay(after: cursor)
            dates.append(cursor)
        }
        return dates
    }

    /// Working days from `start` through `end`, inclusive. Weekends are skipped.
    func workingDays(from start: Date, through end: Date) -> [Date] {
        let begin = nextWorkingDay(onOrAfter: start)
        let last = startOfDay(end)
        guard begin <= last else { return [] }

        var dates: [Date] = []
        var cursor = begin
        while cursor <= last {
            dates.append(cursor)
            let next = nextWorkingDay(after: cursor)
            if next <= cursor { break }
            cursor = next
        }
        return dates
    }

    func date(byAddingDays days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? startOfDay(date)
    }

    func contains(_ date: Date, in dates: Set<Date>) -> Bool {
        dates.contains(startOfDay(date))
    }

    func normalizedSet(_ dates: some Sequence<Date>) -> Set<Date> {
        Set(dates.map(startOfDay))
    }
}

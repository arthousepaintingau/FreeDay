import Foundation

/// Working-day offsets from today using FreeDay’s Australia default week (Mon–Fri, Sydney).
enum UITestWorkingDays {
    static func date(offsetWorkingDays offset: Int, from now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_AU")
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        calendar.firstWeekday = 2
        var cursor = calendar.startOfDay(for: now)
        while !isWorking(cursor, calendar: calendar) {
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        var remaining = offset
        while remaining > 0 {
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
            if isWorking(cursor, calendar: calendar) {
                remaining -= 1
            }
        }
        return cursor
    }

    static func iso(_ offset: Int, from now: Date = Date()) -> String {
        let date = date(offsetWorkingDays: offset, from: now)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func weekdayName(_ offset: Int, from now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date(offsetWorkingDays: offset, from: now))
    }

    private static func isWorking(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday >= 2 && weekday <= 6
    }
}

import SwiftUI

struct DateFormatters {
    private let calendar: Calendar
    private let locale: Locale

    init(workingCalendar: WorkingCalendar) {
        self.calendar = workingCalendar.calendar
        self.locale = workingCalendar.calendar.locale ?? Locale(identifier: workingCalendar.settings.localeIdentifier)
    }

    func weekday(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated).locale(locale))
    }

    func weekdayFull(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).weekday(.wide).locale(locale))
    }

    func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).month(.abbreviated).day().locale(locale))
    }

    func mediumDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).weekday(.abbreviated).month(.abbreviated).day().locale(locale))
    }

    func range(start: Date, end: Date) -> String {
        if calendar.isDate(start, inSameDayAs: end) {
            return mediumDate(start)
        }
        return "\(shortDate(start)) → \(shortDate(end))"
    }

    /// Compact card dates such as "Wed 2 Sep".
    func compactDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(calendar: calendar)
                .weekday(.abbreviated)
                .day()
                .month(.abbreviated)
                .locale(locale)
        )
    }

    func compactRange(start: Date, end: Date) -> String {
        if calendar.isDate(start, inSameDayAs: end) {
            return compactDate(start)
        }
        return "\(compactDate(start)) → \(compactDate(end))"
    }

    func dayNumber(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).day().locale(locale))
    }

    func dayAndMonth(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).day().month(.wide).locale(locale))
    }

    func fullDate(_ date: Date) -> String {
        "\(weekdayFull(date)) \(dayAndMonth(date))"
    }

    func fullRange(start: Date, end: Date) -> String {
        if calendar.isDate(start, inSameDayAs: end) {
            return fullDate(start)
        }
        return "\(fullDate(start)) → \(fullDate(end))"
    }

    func weekRange(monday: Date, friday: Date) -> String {
        "\(mediumDate(monday)) → \(mediumDate(friday))"
    }

    func monthTitle(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(calendar: calendar).month(.wide).year().locale(locale))
    }
}

import Foundation
@testable import FreeDay
import Testing

struct WorkingCalendarTests {
    private let calendar = WorkingCalendar.australiaDefault

    @Test("Monday through Friday are working days")
    func weekdaysAreWorkingDays() {
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-08-31")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-01")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-02")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-03")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-04")))
    }

    @Test("Saturday and Sunday are not working days")
    func weekendIsOff() {
        #expect(!calendar.isWorkingDay(TestCalendar.date("2026-09-05")))
        #expect(!calendar.isWorkingDay(TestCalendar.date("2026-09-06")))
    }

    @Test("Configurable working week can include Saturday")
    func customWorkingWeek() {
        var settings = WorkWeekSettings.australiaDefault
        settings.workingWeekdays = [2, 3, 4, 5, 6, 7]
        let saturdayOn = WorkingCalendar(settings: settings)
        #expect(saturdayOn.isWorkingDay(TestCalendar.date("2026-09-05")))
        #expect(!saturdayOn.isWorkingDay(TestCalendar.date("2026-09-06")))
    }
}

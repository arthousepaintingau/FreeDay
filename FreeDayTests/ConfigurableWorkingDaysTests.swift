import Foundation
@testable import FreeDay
import Testing

struct ConfigurableWorkingDaysTests {
    private let friday = TestCalendar.date("2026-09-04")
    private let saturday = TestCalendar.date("2026-09-05")
    private let sunday = TestCalendar.date("2026-09-06")
    private let monday = TestCalendar.date("2026-08-31")

    private func engine(saturday: Bool = false, sunday: Bool = false) -> SchedulingEngine {
        TestCalendar.makeEngine(worksSaturday: saturday, worksSunday: sunday)
    }

    private func search(saturday: Bool = false, sunday: Bool = false) -> AvailabilitySearch {
        AvailabilitySearch(engine: engine(saturday: saturday, sunday: sunday))
    }

    private func presentation(saturday: Bool = false, sunday: Bool = false) -> CalendarPresentation {
        CalendarPresentation(engine: engine(saturday: saturday, sunday: sunday))
    }

    private func isos(_ dates: [Date]) -> [String] {
        dates.map(TestCalendar.iso)
    }

    // MARK: - Configuration

    @Test("1. Default Monday–Friday configuration")
    func defaultMondayThroughFriday() {
        let settings = WorkWeekSettings.australiaDefault
        #expect(settings.workingWeekdays == [2, 3, 4, 5, 6])
        #expect(settings.worksSaturday == false)
        #expect(settings.worksSunday == false)
        let calendar = WorkingCalendar.australiaDefault
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-08-31")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-01")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-02")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-03")))
        #expect(calendar.isWorkingDay(TestCalendar.date("2026-09-04")))
    }

    @Test("2. Saturday disabled")
    func saturdayDisabled() {
        let calendar = WorkingCalendar(settings: .australia(worksSaturday: false, worksSunday: false))
        #expect(!calendar.isWorkingDay(saturday))
        #expect(engine().availability(on: saturday, projects: []) == .nonWorking)
    }

    @Test("3. Sunday disabled")
    func sundayDisabled() {
        let calendar = WorkingCalendar(settings: .australia(worksSaturday: false, worksSunday: false))
        #expect(!calendar.isWorkingDay(sunday))
        #expect(engine().availability(on: sunday, projects: []) == .nonWorking)
    }

    @Test("4. Saturday enabled")
    func saturdayEnabled() {
        let calendar = WorkingCalendar(settings: .australia(worksSaturday: true))
        #expect(calendar.isWorkingDay(saturday))
        #expect(!calendar.isWorkingDay(sunday))
        #expect(engine(saturday: true).availability(on: saturday, projects: []) == .free)
        #expect(engine(saturday: true).availability(on: sunday, projects: []) == .nonWorking)
    }

    @Test("5. Sunday enabled")
    func sundayEnabled() {
        let calendar = WorkingCalendar(settings: .australia(worksSunday: true))
        #expect(!calendar.isWorkingDay(saturday))
        #expect(calendar.isWorkingDay(sunday))
        #expect(engine(sunday: true).availability(on: saturday, projects: []) == .nonWorking)
        #expect(engine(sunday: true).availability(on: sunday, projects: []) == .free)
    }

    @Test("6. Both weekend days enabled")
    func bothWeekendDaysEnabled() {
        let calendar = WorkingCalendar(settings: .australia(worksSaturday: true, worksSunday: true))
        #expect(calendar.isWorkingDay(saturday))
        #expect(calendar.isWorkingDay(sunday))
        let scheduling = engine(saturday: true, sunday: true)
        #expect(scheduling.availability(on: saturday, projects: []) == .free)
        #expect(scheduling.availability(on: sunday, projects: []) == .free)
        #expect(WorkWeekSettings.australia(worksSaturday: true, worksSunday: true).workingWeekdays == [1, 2, 3, 4, 5, 6, 7])
    }

    // MARK: - Duration

    @Test("7. Friday + 3-day duration with default Mon–Fri")
    func fridayThreeDaysDefault() {
        let dates = engine().workingDates(start: friday, duration: 3)
        #expect(isos(dates) == ["2026-09-04", "2026-09-07", "2026-09-08"])
    }

    @Test("8. Friday + 3-day duration with Saturday enabled")
    func fridayThreeDaysSaturdayOn() {
        let dates = engine(saturday: true).workingDates(start: friday, duration: 3)
        #expect(isos(dates) == ["2026-09-04", "2026-09-05", "2026-09-07"])
    }

    @Test("9. Friday + 3-day duration with Saturday and Sunday enabled")
    func fridayThreeDaysWeekendOn() {
        let dates = engine(saturday: true, sunday: true).workingDates(start: friday, duration: 3)
        #expect(isos(dates) == ["2026-09-04", "2026-09-05", "2026-09-06"])
    }

    // MARK: - Buffer

    @Test("10. Buffer crossing a disabled weekend")
    func bufferCrossesDisabledWeekend() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 1)
        let scheduling = engine()
        #expect(isos(scheduling.jobDates(for: project)) == ["2026-09-04"])
        #expect(isos(scheduling.bufferDates(for: project)) == ["2026-09-07"])
        #expect(scheduling.availability(on: saturday, projects: [project]) == .nonWorking)
        #expect(scheduling.availability(on: sunday, projects: [project]) == .nonWorking)
        #expect(scheduling.availability(on: TestCalendar.date("2026-09-07"), projects: [project]) == .booked)
    }

    @Test("11. Buffer crossing an enabled Saturday")
    func bufferCrossesEnabledSaturday() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 1)
        let scheduling = engine(saturday: true)
        #expect(isos(scheduling.jobDates(for: project)) == ["2026-09-04"])
        #expect(isos(scheduling.bufferDates(for: project)) == ["2026-09-05"])
        #expect(scheduling.availability(on: saturday, projects: [project]) == .booked)
        #expect(scheduling.availability(on: sunday, projects: [project]) == .nonWorking)
        #expect(scheduling.availability(on: TestCalendar.date("2026-09-07"), projects: [project]) == .free)
    }

    // MARK: - Find Free Days

    @Test("12. Find Free Days skips disabled weekends")
    func findFreeDaysSkipsDisabledWeekends() throws {
        let result = search().findSlots(duration: 3, from: friday, projects: [])
        let next = try #require(result.next)
        #expect(isos(next.workingDates) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        #expect(!result.slots.contains { $0.workingDates.contains(saturday) })
        #expect(!result.slots.contains { $0.workingDates.contains(sunday) })
    }

    @Test("13. Find Free Days includes enabled weekends")
    func findFreeDaysIncludesEnabledWeekends() throws {
        let saturdaySearch = search(saturday: true)
        let saturdayResult = saturdaySearch.findSlots(duration: 1, from: friday, projects: [])
        #expect(saturdayResult.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-05"))
        #expect(!saturdayResult.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-06"))

        let bothResult = search(saturday: true, sunday: true).findSlots(duration: 3, from: friday, projects: [])
        let next = try #require(bothResult.next)
        #expect(isos(next.workingDates) == ["2026-09-04", "2026-09-05", "2026-09-06"])
    }

    // MARK: - Quick Check / Specific Date

    @Test("14. Quick Check reports disabled weekend as OFF")
    func quickCheckDisabledWeekendIsOff() {
        #expect(engine().availability(on: saturday, projects: []) == .nonWorking)
        #expect(engine().availability(on: sunday, projects: []) == .nonWorking)
        let snapped = SpecificDateCheck(requestedDate: saturday, duration: 1)
            .snappedStart(using: WorkingCalendar.australiaDefault)
        #expect(TestCalendar.iso(snapped) == "2026-09-07")
    }

    @Test("15. Quick Check can report enabled weekend as FREE")
    func quickCheckEnabledWeekendCanBeFree() throws {
        let scheduling = engine(saturday: true)
        #expect(scheduling.availability(on: saturday, projects: []) == .free)

        let result = QuickCheck(from: saturday, duration: 1).result(
            search: search(saturday: true),
            projects: []
        )
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-09-05")

        let specific = SpecificDateCheck(requestedDate: saturday, duration: 1).evaluate(
            engine: scheduling,
            search: search(saturday: true),
            projects: []
        )
        #expect(specific.isAvailable)
        #expect(TestCalendar.iso(specific.start) == "2026-09-05")
    }

    // MARK: - Reschedule

    @Test("16. Reschedule excludes disabled weekends")
    func rescheduleExcludesDisabledWeekends() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let planner = ReschedulePlanner(engine: engine())
        let result = planner.alternatives(for: project, among: [project], now: monday)
        #expect(result.slots.contains { TestCalendar.iso($0.start) == "2026-09-05" } == false)
        #expect(result.slots.contains { TestCalendar.iso($0.start) == "2026-09-06" } == false)
        for slot in result.slots {
            #expect(slot.workingDates.allSatisfy { engine().workingCalendar.isWorkingDay($0) })
        }
    }

    @Test("17. Reschedule includes enabled weekends")
    func rescheduleIncludesEnabledWeekends() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let saturdayEngine = engine(saturday: true)
        let planner = ReschedulePlanner(
            engine: saturdayEngine,
            options: AvailabilitySearchOptions(calendarDayHorizon: 90, resultLimit: 8)
        )
        let result = planner.alternatives(for: project, among: [project], now: monday)
        #expect(result.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-05"))
        #expect(!result.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-06"))
        let saturdayPreview = try #require(planner.preview(start: friday, duration: 3))
        #expect(isos(saturdayPreview.workingDates) == ["2026-09-04", "2026-09-05", "2026-09-07"])

        let bothPlanner = ReschedulePlanner(
            engine: engine(saturday: true, sunday: true),
            options: AvailabilitySearchOptions(calendarDayHorizon: 90, resultLimit: 8)
        )
        let both = bothPlanner.alternatives(for: project, among: [project], now: monday)
        #expect(both.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-05"))
        #expect(both.slots.map { TestCalendar.iso($0.start) }.contains("2026-09-06"))
        let weekendPreview = try #require(bothPlanner.preview(start: friday, duration: 3))
        #expect(isos(weekendPreview.workingDates) == ["2026-09-04", "2026-09-05", "2026-09-06"])
    }

    // MARK: - Persistence

    @Test("18. Settings persist")
    @MainActor
    func settingsPersist() {
        let suiteName = "au.freeday.tests.workweek.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WorkWeekStore(defaults: defaults)
        #expect(store.worksSaturday == false)
        #expect(store.worksSunday == false)
        #expect(store.settings == .australiaDefault)

        store.worksSaturday = true
        store.worksSunday = true
        #expect(defaults.bool(forKey: WorkWeekStore.saturdayKey))
        #expect(defaults.bool(forKey: WorkWeekStore.sundayKey))

        let reloaded = WorkWeekStore(defaults: defaults)
        #expect(reloaded.worksSaturday)
        #expect(reloaded.worksSunday)
        #expect(reloaded.settings.workingWeekdays == [1, 2, 3, 4, 5, 6, 7])

        reloaded.worksSaturday = false
        let afterOff = WorkWeekStore(defaults: defaults)
        #expect(afterOff.worksSaturday == false)
        #expect(afterOff.worksSunday)
        #expect(afterOff.settings == .australia(worksSunday: true))
    }

    @Test("Unset preferences keep Monday–Friday for existing users")
    @MainActor
    func missingKeysKeepMondayFriday() {
        let suiteName = "au.freeday.tests.workweek.empty.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = WorkWeekStore(defaults: defaults)
        #expect(store.worksSaturday == false)
        #expect(store.worksSunday == false)
        #expect(store.settings.workingWeekdays == WorkWeekSettings.mondayThroughFriday)
    }

    // MARK: - Calendar, Coming, occupancy

    @Test("Enabled Saturday with no jobs is FREE on the calendar")
    func enabledSaturdayEmptyIsFree() {
        let week = presentation(saturday: true).week(containing: monday, projects: [], now: monday)
        #expect(week.day(iso: "2026-09-05")?.kind == .free)
        #expect(week.day(iso: "2026-09-05")?.isWorkingDay == true)
        #expect(week.day(iso: "2026-09-06")?.kind == .nonWorking)
        #expect(week.workingDays.map(\.isoDate).contains("2026-09-05"))
    }

    @Test("Enabled weekend with a BOOKED job displays BOOKED")
    func enabledWeekendBookedOccupancy() {
        let job = TestCalendar.project(status: .booked, start: "2026-09-05", duration: 1)
        let week = presentation(saturday: true).week(containing: monday, projects: [job], now: monday)
        #expect(week.day(iso: "2026-09-05")?.kind == .booked)
        #expect(week.day(iso: "2026-09-05")?.isWorkingDay == true)
        #expect(engine(saturday: true).availability(on: saturday, projects: [job]) == .booked)
    }

    @Test("Enabled weekend with BUFFER displays BUFFER")
    func enabledWeekendBufferOccupancy() {
        let job = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 1)
        let week = presentation(saturday: true).week(containing: monday, projects: [job], now: monday)
        #expect(week.day(iso: "2026-09-05")?.kind == .buffer)
        #expect(engine(saturday: true).availability(on: saturday, projects: [job]) == .booked)
    }

    @Test("Quoted weekend does not block when Saturday is enabled")
    func quotedWeekendDoesNotBlock() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-09-05", duration: 1)
        let scheduling = engine(saturday: true)
        #expect(scheduling.availability(on: saturday, projects: [quoted]) == .tentative)
        #expect(scheduling.occupiedDates(from: [quoted]).isEmpty)
        let week = presentation(saturday: true).week(containing: monday, projects: [quoted], now: monday)
        #expect(week.day(iso: "2026-09-05")?.kind == .quoted)
    }

    @Test("Completed weekend does not block when Saturday is enabled")
    func completedWeekendDoesNotBlock() {
        let done = TestCalendar.project(status: .completed, start: "2026-09-05", duration: 1)
        let scheduling = engine(saturday: true)
        #expect(scheduling.availability(on: saturday, projects: [done]) == .free)
        let week = presentation(saturday: true).week(containing: monday, projects: [done], now: monday)
        #expect(week.day(iso: "2026-09-05")?.kind == .completed)
        #expect(week.day(iso: "2026-09-05")?.canUseDay == true)
    }

    @Test("What’s Coming treats enabled weekends as working days")
    func comingIncludesEnabledWeekends() {
        let defaultComing = ComingCapacityBuilder(engine: engine()).make(projects: [], now: monday)
        #expect(defaultComing.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(defaultComing.workingDayCount == 10)

        let saturdayComing = ComingCapacityBuilder(engine: engine(saturday: true)).make(projects: [], now: monday)
        #expect(saturdayComing.day(iso: "2026-09-05")?.kind == .free)
        #expect(saturdayComing.day(iso: "2026-09-06")?.kind == .nonWorking)
        #expect(saturdayComing.workingDayCount == 12)

        let bothComing = ComingCapacityBuilder(engine: engine(saturday: true, sunday: true)).make(
            projects: [],
            now: monday
        )
        #expect(bothComing.day(iso: "2026-09-05")?.kind == .free)
        #expect(bothComing.day(iso: "2026-09-06")?.kind == .free)
        #expect(bothComing.workingDayCount == 14)
    }

    @Test("Changing settings does not mutate stored project dates")
    func changingSettingsLeavesProjectDatesIntact() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 3)
        let originalStart = project.startDate
        let originalDuration = project.durationInWorkingDays

        #expect(isos(engine().workingDates(start: friday, duration: 3)) == [
            "2026-09-04", "2026-09-07", "2026-09-08"
        ])
        #expect(isos(engine(saturday: true).workingDates(start: friday, duration: 3)) == [
            "2026-09-04", "2026-09-05", "2026-09-07"
        ])

        #expect(project.startDate == originalStart)
        #expect(project.durationInWorkingDays == originalDuration)
        #expect(project.startDate == friday)
    }

    @Test("Monday–Friday cannot be turned off by the settings factory")
    func weekdaysRemainOn() {
        let settings = WorkWeekSettings.australia(worksSaturday: false, worksSunday: false)
        #expect(settings.workingWeekdays.isSuperset(of: WorkWeekSettings.mondayThroughFriday))
        for weekday in WorkWeekSettings.mondayThroughFriday {
            #expect(settings.isWorkingWeekday(weekday))
        }
    }
}

import Foundation
@testable import FreeDay
import Testing

struct CalendarPresentationTests {
    private let engine = TestCalendar.engine
    private let presentation = CalendarPresentation(engine: TestCalendar.engine)
    private let now = TestCalendar.date("2026-08-31")
    private let formatters = DateFormatters(workingCalendar: TestCalendar.working)

    @Test("1. Current week rendering")
    func currentWeekRendering() {
        let week = presentation.week(containing: now, projects: [], now: now)

        #expect(TestCalendar.iso(week.start) == "2026-08-31")
        #expect(week.days.count == 7)
        #expect(week.workingDays.map(\.isoDate) == [
            "2026-08-31",
            "2026-09-01",
            "2026-09-02",
            "2026-09-03",
            "2026-09-04"
        ])
        #expect(week.containsToday)
        #expect(week.day(iso: "2026-08-31")?.isToday == true)
        #expect(week.day(iso: "2026-08-31")?.kind == .free)
        #expect(week.personality == "Nice! You’ve got some room.")
        #expect(presentation.isCurrentWeek(now, now: now))
    }

    @Test("2. Future week navigation")
    func futureWeekNavigation() {
        let future = presentation.addingWeeks(1, to: now)
        let week = presentation.week(containing: future, projects: [], now: now)

        #expect(TestCalendar.iso(week.start) == "2026-09-07")
        #expect(week.containsToday == false)
        #expect(presentation.isCurrentWeek(future, now: now) == false)
    }

    @Test("3. Previous week navigation")
    func previousWeekNavigation() {
        let previous = presentation.addingWeeks(-1, to: now)
        let week = presentation.week(containing: previous, projects: [], now: now)

        #expect(TestCalendar.iso(week.start) == "2026-08-24")
        #expect(week.containsToday == false)
    }

    @Test("4. Today navigation")
    func todayNavigation() {
        var visible = presentation.addingWeeks(2, to: now)
        #expect(presentation.isCurrentWeek(visible, now: now) == false)

        visible = now
        #expect(presentation.isCurrentWeek(visible, now: now))
        let week = presentation.week(containing: visible, projects: [], now: now)
        #expect(week.containsToday)
        #expect(week.day(iso: "2026-08-31")?.isToday == true)
    }

    @Test("5. Booked project appears on correct working days")
    func bookedProjectOnWorkingDays() {
        let smith = TestCalendar.project(
            name: "Interior",
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        let week = presentation.week(containing: now, projects: [smith], now: now)

        for iso in ["2026-08-31", "2026-09-01", "2026-09-02"] {
            let day = week.day(iso: iso)
            #expect(day?.kind == .booked)
            #expect(day?.displayName == "Smith House")
            #expect(day?.durationHint == "3 days")
            #expect(day?.spokenLabel(fullDate: formatters.fullDate(day!.date)).contains("Booked") == true)
            #expect(day?.spokenLabel(fullDate: formatters.fullDate(day!.date)).contains("Smith House") == true)
        }
        #expect(week.day(iso: "2026-09-03")?.kind == .free)
        #expect(week.day(iso: "2026-09-04")?.kind == .free)
        #expect(week.personality == "Looking busy, but you’ve got some room.")

        let fullWeek = presentation.week(
            containing: now,
            projects: [TestCalendar.project(status: .booked, start: "2026-08-31", duration: 5)],
            now: now
        )
        #expect(fullWeek.personality == "😅 You’re fully booked!")
    }

    @Test("6. Quoted project appears as quoted but does not block")
    func quotedDoesNotBlock() {
        let quoted = TestCalendar.project(
            customer: "Johnson House",
            status: .quoted,
            start: "2026-09-04",
            duration: 1
        )
        let week = presentation.week(containing: now, projects: [quoted], now: now)
        let friday = week.day(iso: "2026-09-04")

        #expect(friday?.kind == .quoted)
        #expect(friday?.displayName == "Johnson House")
        #expect(friday?.kind.badgeTitle == "Quoted")
        #expect(engine.availability(on: TestCalendar.date("2026-09-04"), projects: [quoted]) == .tentative)
        #expect(engine.occupiedDates(from: [quoted]).isEmpty)
        #expect(
            engine.findFreeSlots(
                duration: 1,
                from: TestCalendar.date("2026-09-04"),
                projects: [quoted],
                resultLimit: 1
            ).first?.start == TestCalendar.date("2026-09-04")
        )
        #expect(week.personality == "Nice! You’ve got some room.")
    }

    @Test("7. Completed project does not block")
    func completedDoesNotBlock() {
        let done = TestCalendar.project(
            customer: "Old Job",
            status: .completed,
            start: "2026-08-31",
            duration: 3
        )
        let week = presentation.week(containing: now, projects: [done], now: now)

        for iso in ["2026-08-31", "2026-09-01", "2026-09-02"] {
            let day = week.day(iso: iso)
            #expect(day?.kind == .completed)
            #expect(day?.canUseDay == true)
            #expect(engine.availability(on: day!.date, projects: [done]) == .free)
        }
        #expect(engine.occupiedDates(from: [done]).isEmpty)
        #expect(week.personality == "Nice! You’ve got some room.")
    }

    @Test("8. Multi-day project spans correct working days")
    func multiDaySpansWorkingDays() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-09-04",
            duration: 3
        )
        let week = presentation.week(containing: now, projects: [smith], now: now)
        let next = presentation.week(
            containing: presentation.addingWeeks(1, to: now),
            projects: [smith],
            now: now
        )

        #expect(week.day(iso: "2026-09-04")?.kind == .booked)
        #expect(week.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(week.day(iso: "2026-09-06")?.kind == .nonWorking)
        #expect(next.day(iso: "2026-09-07")?.kind == .booked)
        #expect(next.day(iso: "2026-09-08")?.kind == .booked)
        #expect(next.day(iso: "2026-09-09")?.kind == .free)
        #expect(engine.workingDates(start: smith.startDate!, duration: 3).map(TestCalendar.iso) == [
            "2026-09-04",
            "2026-09-07",
            "2026-09-08"
        ])
    }

    @Test("9. Weekend is not counted as a working day")
    func weekendIsNotWorking() {
        let booked = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 2)
        let week = presentation.week(containing: now, projects: [booked], now: now)

        #expect(week.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(week.day(iso: "2026-09-06")?.kind == .nonWorking)
        #expect(week.day(iso: "2026-09-05")?.isWorkingDay == false)
        #expect(week.weekendDays.count == 2)
        #expect(week.day(iso: "2026-09-05")?.projectToOpen == nil)
    }

    @Test("10. Month view reflects project status")
    func monthViewReflectsStatus() {
        let booked = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        let quoted = TestCalendar.project(
            customer: "Johnson House",
            status: .quoted,
            start: "2026-09-04",
            duration: 1
        )
        let month = presentation.month(
            containing: TestCalendar.date("2026-09-01"),
            projects: [booked, quoted],
            now: now
        )

        #expect(formatters.monthTitle(month.monthStart) == "September 2026")
        #expect(month.day(iso: "2026-09-01")?.kind == .booked)
        #expect(month.day(iso: "2026-09-02")?.kind == .booked)
        #expect(month.day(iso: "2026-09-03")?.kind == .free)
        #expect(month.day(iso: "2026-09-04")?.kind == .quoted)
        #expect(month.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(month.day(iso: "2026-09-01")?.displayName == "Smith House")
    }

    @Test("11. Editing a project updates calendar data")
    func editingProjectUpdatesCalendar() {
        var project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        var week = presentation.week(containing: now, projects: [project], now: now)
        #expect(week.day(iso: "2026-09-02")?.kind == .booked)

        project.durationInWorkingDays = 1
        week = presentation.week(containing: now, projects: [project], now: now)
        #expect(week.day(iso: "2026-08-31")?.kind == .booked)
        #expect(week.day(iso: "2026-09-01")?.kind == .free)
        #expect(week.day(iso: "2026-09-02")?.kind == .free)
    }

    @Test("12. Completing a project updates calendar availability")
    func completingProjectUpdatesAvailability() {
        var project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        var week = presentation.week(containing: now, projects: [project], now: now)
        #expect(week.workingDays.filter { $0.kind == .booked }.count == 3)

        project.status = .completed
        project.completedDate = now
        week = presentation.week(containing: now, projects: [project], now: now)

        #expect(week.day(iso: "2026-08-31")?.kind == .completed)
        #expect(week.day(iso: "2026-08-31")?.canUseDay == true)
        #expect(engine.availability(on: now, projects: [project]) == .free)
        #expect(week.personality == "Nice! You’ve got some room.")
    }

    @Test("13. Deleting a project removes it from calendar")
    func deletingProjectRemovesFromCalendar() {
        let project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        var projects = [project]
        var week = presentation.week(containing: now, projects: projects, now: now)
        #expect(week.day(iso: "2026-08-31")?.kind == .booked)

        projects.removeAll()
        week = presentation.week(containing: now, projects: projects, now: now)
        #expect(week.day(iso: "2026-08-31")?.kind == .free)
        #expect(week.day(iso: "2026-09-01")?.kind == .free)
        #expect(week.day(iso: "2026-09-02")?.kind == .free)
        #expect(week.days.allSatisfy { $0.projectToOpen == nil })
    }

    @Test("14. Free day can open Add Project with correct date")
    func freeDayPrefillDate() {
        let week = presentation.week(containing: now, projects: [], now: now)
        let wednesday = week.day(iso: "2026-09-02")

        #expect(wednesday?.canUseDay == true)
        #expect(wednesday?.kind == .free)
        #expect(wednesday?.projectToOpen == nil)

        let prefill = ProjectPrefill(
            startDate: wednesday?.date,
            durationInWorkingDays: 1,
            status: .booked
        )
        #expect(prefill.startDate == TestCalendar.date("2026-09-02"))
    }

    @Test("15. Booked day opens the correct project")
    func bookedDayOpensCorrectProject() {
        let smithID = UUID()
        let smith = TestCalendar.project(
            id: smithID,
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        let other = TestCalendar.project(
            customer: "Other House",
            status: .booked,
            start: "2026-09-03",
            duration: 1
        )
        let week = presentation.week(containing: now, projects: [smith, other], now: now)

        #expect(week.day(iso: "2026-08-31")?.projectToOpen?.id == smithID)
        #expect(week.day(iso: "2026-09-01")?.projectToOpen?.id == smithID)
        #expect(week.day(iso: "2026-09-02")?.projectToOpen?.id == smithID)
        #expect(week.day(iso: "2026-09-03")?.projectToOpen?.customerName == "Other House")
        #expect(week.personality == "Looking busy, but you’ve got some room.")
    }
}

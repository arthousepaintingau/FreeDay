import Foundation
import SwiftData
@testable import FreeDay
import Testing

struct QuickCheckTests {
    private let engine = TestCalendar.engine
    private let search = AvailabilitySearch(engine: TestCalendar.engine)
    private let today = TestCalendar.date("2026-08-31")

    private func check(
        duration: Int = 3,
        from: String = "2026-08-31",
        horizon: Int = 90,
        projects: [ProjectSnapshot] = []
    ) -> AvailabilitySearchResult {
        QuickCheck(
            from: TestCalendar.date(from),
            duration: duration,
            horizonDays: horizon
        ).result(search: search, projects: projects)
    }

    @Test("1. Default duration is 3 days")
    func defaultDurationIsThree() {
        let quick = QuickCheck(from: today)
        #expect(quick.duration == 3)
        #expect(QuickCheck.defaultDuration == 3)
    }

    @Test("2. Range allows 1–30 days")
    func durationRange() {
        var quick = QuickCheck(from: today, duration: 0)
        #expect(quick.duration == 1)
        quick.setDuration(31)
        #expect(quick.duration == 30)
        quick.setDuration(1)
        #expect(quick.duration == 1)
        quick.setDuration(30)
        #expect(quick.duration == 30)
    }

    @Test("3. Changing duration recalculates automatically")
    func changingDurationRecalculates() {
        let one = check(duration: 1)
        let three = check(duration: 3)
        #expect(one.next?.durationWorkingDays == 1)
        #expect(three.next?.durationWorkingDays == 3)
        #expect(TestCalendar.iso(three.next?.end ?? .distantPast) == "2026-09-02")
    }

    @Test("4. Earliest slot matches Find Free Days for the same inputs")
    func matchesFindFreeDays() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let projects = [booked]
        let find = search.findSlots(duration: 3, from: today, projects: projects)
        let quick = check(duration: 3, projects: projects)
        #expect(find.slots.map(\.start) == quick.slots.map(\.start))
        #expect(find.next?.workingDates == quick.next?.workingDates)
    }

    @Test("5. Other options are chronological")
    func otherOptionsAreChronological() {
        let result = check(duration: 1)
        let starts = result.slots.map(\.start)
        #expect(starts == starts.sorted())
        #expect(result.next?.start == starts.first)
    }

    @Test("6. Booked project blocks Quick Check")
    func bookedBlocks() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let result = check(duration: 1, projects: [booked])
        #expect(TestCalendar.iso(result.next?.start ?? .distantPast) == "2026-09-01")
    }

    @Test("7. Buffer blocks Quick Check")
    func bufferBlocks() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let result = check(duration: 1, projects: [booked])
        #expect(TestCalendar.iso(result.next?.start ?? .distantPast) == "2026-09-04")
        #expect(result.slots.contains { TestCalendar.iso($0.start) == "2026-09-03" } == false)
    }

    @Test("8. Quoted project does not block")
    func quotedDoesNotBlock() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 5, buffer: 2)
        let result = check(duration: 3, projects: [quoted])
        #expect(TestCalendar.iso(result.next?.start ?? .distantPast) == "2026-08-31")
    }

    @Test("9. Completed project does not block")
    func completedDoesNotBlock() {
        let done = TestCalendar.project(status: .completed, start: "2026-08-31", duration: 5, buffer: 2)
        let result = check(duration: 3, projects: [done])
        #expect(TestCalendar.iso(result.next?.start ?? .distantPast) == "2026-08-31")
    }

    @Test("10. Weekend does not count")
    func weekendDoesNotCount() throws {
        let result = check(duration: 3, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(next.workingDates.map(TestCalendar.iso) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        #expect(!next.workingDates.map(TestCalendar.iso).contains("2026-09-05"))
    }

    @Test("11. Friday + 3 working days ends Tuesday")
    func fridayThreeDaysEndsTuesday() throws {
        let result = check(duration: 3, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-09-04")
        #expect(TestCalendar.iso(next.end) == "2026-09-08")
    }

    @Test("12. Start-from Today works")
    func startFromToday() throws {
        let result = check(duration: 3, from: "2026-08-31")
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-08-31")
    }

    @Test("13. Custom FROM date works")
    func customFromDate() throws {
        let result = check(duration: 3, from: "2026-09-21")
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-09-21")
        #expect(TestCalendar.iso(next.end) == "2026-09-23")
    }

    @Test("14. Weekend FROM date follows working-day rules")
    func weekendFromDateSnapsToWorkingDay() throws {
        let result = check(duration: 3, from: "2026-09-05")
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-09-07")
        #expect(TestCalendar.iso(next.end) == "2026-09-09")
    }

    @Test("15-16. No slot within 90 days; Search Further finds a later slot")
    func searchFurtherExtendsHorizon() throws {
        let wall = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 80)
        let first = check(duration: 3, horizon: 90, projects: [wall])
        #expect(first.isEmpty)
        #expect(first.horizonDays == 90)

        var quick = QuickCheck(from: today, duration: 3, horizonDays: 90)
        #expect(quick.canSearchFurther)
        quick.searchFurther()
        #expect(quick.horizonDays == 180)
        let extended = quick.result(search: search, projects: [wall])
        #expect(!extended.isEmpty)
        #expect(extended.horizonDays == 180)
        let next = try #require(extended.next)
        #expect(TestCalendar.iso(next.start) > "2026-08-31")
    }

    @Test("17. Search Further does not alter project data")
    func searchFurtherIsReadOnly() {
        var project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let original = project
        var quick = QuickCheck(from: today, duration: 3)
        quick.searchFurther()
        _ = quick.result(search: search, projects: [project])
        #expect(project == original)
        #expect(project.startDate == original.startDate)
        #expect(project.bufferInWorkingDays == 1)
    }

    @Test("23. Results respect multi-day booked projects")
    func multiDayBooked() throws {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 5)
        let result = check(duration: 3, projects: [booked])
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-09-07")
    }

    @Test("24. Results respect multi-day buffers")
    func multiDayBuffer() throws {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1, buffer: 3)
        let result = check(duration: 1, projects: [booked])
        #expect(TestCalendar.iso(result.next?.start ?? .distantPast) == "2026-09-04")
    }

    @Test("25. Duration change from 1 → 30 remains stable")
    func durationOneToThirty() {
        let one = check(duration: 1)
        let thirty = check(duration: 30)
        #expect(one.next?.durationWorkingDays == 1)
        #expect(thirty.next?.durationWorkingDays == 30)
        #expect(thirty.next?.start == one.next?.start)
    }

    @Test("Personality follows the result, not a random rotation")
    func personalityIsDerivedFromResult() {
        let quick = QuickCheck(from: today, duration: 3)
        #expect(quick.message(for: AvailabilitySearchResult(slots: [], horizonDays: 90)) == PersonalityCopy.fullyBooked)

        let only = AvailabilitySearchResult(slots: [slot(start: "2026-08-31", duration: 3)], horizonDays: 90)
        #expect(quick.message(for: only) == PersonalityCopy.perfectFit)

        let busy = AvailabilitySearchResult(
            slots: [
                slot(start: "2026-08-31", duration: 3),
                slot(start: "2026-09-03", duration: 3)
            ],
            horizonDays: 90
        )
        #expect(quick.message(for: busy) == PersonalityCopy.lookingBusy)

        let plenty = AvailabilitySearchResult(
            slots: [
                slot(start: "2026-08-31", duration: 3),
                slot(start: "2026-09-03", duration: 3),
                slot(start: "2026-09-08", duration: 3),
                slot(start: "2026-09-11", duration: 3)
            ],
            horizonDays: 90
        )
        #expect(quick.message(for: plenty) == PersonalityCopy.plentyOfSpace)
    }

    @Test("18. Opening Quick Check creates no project")
    @MainActor
    func openingCreatesNoProject() throws {
        let container = try Persistence.inMemoryContainer()
        let context = ModelContext(container)
        _ = check(duration: 3)
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    @Test("19. Closing Quick Check creates no project")
    @MainActor
    func closingCreatesNoProject() throws {
        let container = try Persistence.inMemoryContainer()
        let context = ModelContext(container)
        var quick = QuickCheck(from: today, duration: 3)
        _ = quick.result(search: search, projects: [])
        quick.searchFurther()
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    @Test("20. Use These Dates maps onto Add Project prefill")
    func useTheseDatesPrefillsAddProject() throws {
        let result = check(duration: 5)
        let next = try #require(result.next)
        let prefill = ProjectPrefill(
            startDate: next.start,
            durationInWorkingDays: 5,
            status: .booked,
            showFitMessage: true
        )
        #expect(prefill.startDate == next.start)
        #expect(prefill.durationInWorkingDays == 5)
        #expect(prefill.status == .booked)
        #expect(prefill.projectName.isEmpty)
        #expect(prefill.customerName.isEmpty)
        #expect(TestCalendar.iso(next.end) == "2026-09-04")
    }

    @Test("21. Add Project is not automatically saved by Quick Check")
    @MainActor
    func doesNotSaveAProject() throws {
        let container = try Persistence.inMemoryContainer()
        let context = ModelContext(container)
        let result = check(duration: 3)
        #expect(result.next != nil)
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    @Test("22. Existing project data remains unchanged")
    @MainActor
    func existingProjectDataUnchanged() throws {
        let container = try Persistence.inMemoryContainer()
        let context = ModelContext(container)
        let project = Project(
            projectName: "Interior painting",
            customerName: "Smith House",
            status: .booked,
            startDate: TestCalendar.date("2026-08-31"),
            durationInWorkingDays: 3,
            bufferInWorkingDays: 1
        )
        context.insert(project)
        try context.save()

        _ = check(duration: 3, projects: [project.snapshot])
        var quick = QuickCheck(from: today, duration: 3)
        quick.searchFurther()
        _ = quick.result(search: search, projects: [project.snapshot])

        let fetched = try context.fetch(FetchDescriptor<Project>())
        #expect(fetched.count == 1)
        #expect(fetched[0].projectName == "Interior painting")
        #expect(fetched[0].customerName == "Smith House")
        #expect(fetched[0].status == .booked)
        #expect(fetched[0].durationInWorkingDays == 3)
        #expect(fetched[0].bufferInWorkingDays == 1)
        #expect(fetched[0].startDate == TestCalendar.date("2026-08-31"))
    }

    private func slot(start: String, duration: Int) -> FreeSlot {
        let dates = engine.workingDates(start: TestCalendar.date(start), duration: duration)
        return FreeSlot(start: dates[0], end: dates[dates.count - 1], workingDates: dates)
    }
}

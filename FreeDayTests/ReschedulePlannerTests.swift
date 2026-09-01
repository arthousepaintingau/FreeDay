import Foundation
import SwiftData
@testable import FreeDay
import Testing

struct ReschedulePlannerTests {
    private let engine = TestCalendar.engine
    private let now = TestCalendar.date("2026-08-31")
    private let presentation = CalendarPresentation(engine: TestCalendar.engine)

    private func planner(horizon: Int = 90, limit: Int = 5) -> ReschedulePlanner {
        ReschedulePlanner(
            engine: engine,
            options: AvailabilitySearchOptions(calendarDayHorizon: horizon, resultLimit: limit)
        )
    }

    private func isos(_ slot: FreeSlot) -> [String] {
        slot.workingDates.map(TestCalendar.iso)
    }

    private func alternatives(
        _ project: ProjectSnapshot,
        among projects: [ProjectSnapshot]? = nil,
        searchEarlier: Bool = false,
        from override: Date? = nil,
        horizon: Int = 90
    ) -> AvailabilitySearchResult {
        planner(horizon: horizon).alternatives(
            for: project,
            among: projects ?? [project],
            searchEarlier: searchEarlier,
            from: override,
            now: now
        )
    }

    @Test("1. Reschedule a 1-day project")
    func rescheduleOneDay() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let result = alternatives(project)
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-01"])
        #expect(project.durationInWorkingDays == 1)
    }

    @Test("2. Reschedule a 3-day project")
    func rescheduleThreeDay() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let result = alternatives(project)
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-03", "2026-09-04", "2026-09-07"])
        #expect(next.durationWorkingDays == 3)
    }

    @Test("3. Reschedule a 5-day project")
    func rescheduleFiveDay() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 5)
        let result = alternatives(project)
        let next = try #require(result.next)
        #expect(isos(next) == [
            "2026-09-07",
            "2026-09-08",
            "2026-09-09",
            "2026-09-10",
            "2026-09-11"
        ])
        #expect(next.durationWorkingDays == 5)
    }

    @Test("4. Reschedule across a weekend")
    func rescheduleAcrossWeekend() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 3)
        let current = try #require(planner().currentSlot(for: project))
        #expect(isos(current) == ["2026-09-03", "2026-09-04", "2026-09-07"])
        let next = try #require(alternatives(project).next)
        #expect(isos(next).contains("2026-09-05") == false)
        #expect(isos(next).contains("2026-09-06") == false)
        #expect(next.workingDates.allSatisfy { engine.workingCalendar.isWorkingDay($0) })
    }

    @Test("5. Friday start with 3 working days")
    func fridayStartThreeDays() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 3)
        let current = try #require(planner().currentSlot(for: project))
        #expect(isos(current) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        let next = try #require(alternatives(project).next)
        #expect(isos(next) == ["2026-09-09", "2026-09-10", "2026-09-11"])
    }

    @Test("6. Project being rescheduled does not block its own search")
    func selfDoesNotBlockSearch() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        #expect(engine.occupiedDates(from: [project], excluding: project.id).isEmpty)
        let blocked = engine.findFreeSlots(
            duration: 3,
            from: now,
            projects: [project],
            resultLimit: 1
        )
        #expect(blocked.first.map { TestCalendar.iso($0.start) } == "2026-09-03")
        let next = try #require(alternatives(project).next)
        #expect(TestCalendar.iso(next.start) == "2026-09-03")
        let keep = planner().evaluate(start: now, project: project, among: [project])
        guard case .allowed(let dates) = keep else {
            Issue.record("Own dates must remain valid while moving")
            return
        }
        #expect(dates.map(TestCalendar.iso) == ["2026-08-31", "2026-09-01", "2026-09-02"])
    }

    @Test("7. Other booked projects still block search")
    func otherBookedProjectsStillBlock() throws {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let other = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2)
        let next = try #require(alternatives(moving, among: [moving, other]).next)
        #expect(isos(next) == ["2026-09-07", "2026-09-08", "2026-09-09"])
        #expect(isos(next).contains("2026-09-03") == false)
        #expect(isos(next).contains("2026-09-04") == false)
    }

    @Test("8. Quoted projects do not block")
    func quotedDoesNotBlock() throws {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let quoted = TestCalendar.project(status: .quoted, start: "2026-09-03", duration: 5)
        let next = try #require(alternatives(moving, among: [moving, quoted]).next)
        #expect(isos(next) == ["2026-09-03", "2026-09-04", "2026-09-07"])
    }

    @Test("9. Completed projects do not block")
    func completedDoesNotBlock() throws {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let done = TestCalendar.project(status: .completed, start: "2026-09-03", duration: 5)
        let next = try #require(alternatives(moving, among: [moving, done]).next)
        #expect(isos(next) == ["2026-09-03", "2026-09-04", "2026-09-07"])
    }

    @Test("10. Earliest alternative is returned first")
    func earliestAlternativeFirst() throws {
        let project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-09-07",
            duration: 3
        )
        let defaultSearch = alternatives(project)
        #expect(defaultSearch.slots.first.map { TestCalendar.iso($0.start) } == "2026-09-10")
        #expect(defaultSearch.slots.contains { TestCalendar.iso($0.start) == "2026-08-31" } == false)

        let earlier = alternatives(project, searchEarlier: true)
        #expect(earlier.slots.first.map { TestCalendar.iso($0.start) } == "2026-08-31")
        #expect(planner().searchOrigin(for: project, searchEarlier: false, now: now) == TestCalendar.date("2026-09-07"))
        #expect(planner().searchOrigin(for: project, searchEarlier: true, now: now) == now)
    }

    @Test("11. Alternative results are chronological")
    func alternativesAreChronological() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let starts = alternatives(project).slots.map(\.start)
        #expect(starts == starts.sorted())
        #expect(Set(starts.map(TestCalendar.iso)).count == starts.count)
    }

    @Test("12. Manual date available")
    func manualDateAvailable() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let preview = try #require(planner().preview(start: TestCalendar.date("2026-09-09"), duration: 3))
        #expect(isos(preview) == ["2026-09-09", "2026-09-10", "2026-09-11"])
        let decision = planner().evaluate(start: preview.start, project: project, among: [project])
        guard case .allowed(let dates) = decision else {
            Issue.record("Expected the manual date to be free")
            return
        }
        #expect(dates.map(TestCalendar.iso) == isos(preview))
    }

    @Test("13. Manual date conflict rejected")
    func manualDateConflictRejected() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let other = TestCalendar.project(status: .booked, start: "2026-09-07", duration: 2)
        let decision = planner().evaluate(
            start: TestCalendar.date("2026-09-07"),
            project: moving,
            among: [moving, other]
        )
        guard case .blocked = decision else {
            Issue.record("Expected a conflict against the other booked job")
            return
        }
    }

    @Test("14. Final conflict check before save")
    func finalConflictCheckBeforeSave() throws {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let slot = try #require(alternatives(moving).next)
        let interloper = TestCalendar.project(
            status: .booked,
            start: TestCalendar.iso(slot.start),
            duration: slot.durationWorkingDays
        )
        let decision = planner().evaluate(slot: slot, project: moving, among: [moving, interloper])
        guard case .blocked = decision else {
            Issue.record("A slot taken while the sheet is open must not save")
            return
        }
        #expect(moving.startDate == now)
    }

    @Test("15. Cancel leaves original dates unchanged")
    func cancelLeavesOriginalDates() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let original = project.startDate
        _ = alternatives(project)
        _ = planner().evaluate(start: TestCalendar.date("2026-09-09"), project: project, among: [project])
        #expect(project.startDate == original)
        #expect(project.durationInWorkingDays == 3)
        #expect(try #require(planner().currentSlot(for: project)).start == original)
    }

    @Test("16. Reschedule persists after app relaunch")
    func reschedulePersists() throws {
        let container = try Persistence.inMemoryContainer()
        let id = UUID()
        let write = ModelContext(container)
        write.insert(
            Project(
                id: id,
                projectName: "Interior",
                customerName: "Smith House",
                status: .booked,
                startDate: now,
                durationInWorkingDays: 3
            )
        )
        try write.save()

        let edit = ModelContext(container)
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        let project = try #require(try edit.fetch(descriptor).first)
        let snapshot = project.snapshot
        let slot = try #require(alternatives(snapshot, among: [snapshot]).next)
        guard case .allowed = planner().evaluate(slot: slot, project: snapshot, among: [snapshot]) else {
            Issue.record("Expected the new slot to be allowed")
            return
        }
        project.startDate = slot.start
        try edit.save()

        let read = ModelContext(container)
        let reloaded = try #require(try read.fetch(descriptor).first)
        #expect(reloaded.startDate == slot.start)
        #expect(reloaded.durationInWorkingDays == 3)
        #expect(reloaded.status == .booked)
    }

    @Test("17. Updated dates calculate correctly")
    func updatedDatesCalculateCorrectly() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let slot = try #require(alternatives(project).next)
        var moved = project
        moved.startDate = slot.start
        let dates = engine.workingDates(start: slot.start, duration: moved.durationInWorkingDays)
        #expect(dates.map(TestCalendar.iso) == ["2026-09-03", "2026-09-04", "2026-09-07"])
        #expect(dates.contains { TestCalendar.iso($0) == "2026-09-05" } == false)
        #expect(moved.durationInWorkingDays == 3)
    }

    @Test("18. Multi-day project appears correctly in calendar after reschedule")
    func calendarReflectsReschedule() throws {
        let project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        let slot = try #require(alternatives(project).next)
        var moved = project
        moved.startDate = slot.start
        let week = presentation.week(containing: now, projects: [moved], now: now)
        #expect(week.day(iso: "2026-08-31")?.kind == .free)
        #expect(week.day(iso: "2026-09-01")?.kind == .free)
        #expect(week.day(iso: "2026-09-02")?.kind == .free)
        #expect(week.day(iso: "2026-09-03")?.kind == .booked)
        #expect(week.day(iso: "2026-09-03")?.displayName == "Smith House")
        #expect(week.day(iso: "2026-09-04")?.kind == .booked)
        let nextWeek = presentation.week(
            containing: presentation.addingWeeks(1, to: now),
            projects: [moved],
            now: now
        )
        #expect(nextWeek.day(iso: "2026-09-07")?.kind == .booked)
        let month = presentation.month(containing: TestCalendar.date("2026-09-01"), projects: [moved], now: now)
        #expect(month.day(iso: "2026-09-03")?.kind == .booked)
        #expect(month.day(iso: "2026-08-31")?.kind == .free)
    }

    @Test("19. Find Free Days reflects rescheduled dates")
    func findFreeDaysReflectsReschedule() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let slot = try #require(alternatives(project).next)
        var moved = project
        moved.startDate = slot.start
        let search = AvailabilitySearch(engine: engine).findSlots(
            duration: 1,
            from: now,
            projects: [moved]
        )
        #expect(search.next.map { TestCalendar.iso($0.start) } == "2026-08-31")
        let three = AvailabilitySearch(engine: engine).findSlots(
            duration: 3,
            from: now,
            projects: [moved]
        )
        #expect(three.next.map { TestCalendar.iso($0.start) } == "2026-08-31")
    }

    @Test("20. Home reflects rescheduled dates")
    func homeReflectsReschedule() throws {
        let project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3
        )
        let slot = try #require(alternatives(project).next)
        var moved = project
        moved.startDate = slot.start
        let summary = HomeSummaryBuilder(engine: engine).make(projects: [moved], now: now)
        #expect(summary.todayAvailability == .free)
        #expect(summary.upcoming.first?.startDate == slot.start)
        #expect(summary.upcoming.first?.customerName == "Smith House")
        #expect(summary.nextAvailable == now)
    }

    @Test("21. No alternative within search horizon")
    func noAlternativeWithinHorizon() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let wall = TestCalendar.project(status: .booked, start: "2026-09-01", duration: 20)
        let result = alternatives(moving, among: [moving, wall], horizon: 5)
        #expect(result.isEmpty)
        #expect(moving.startDate == now)
    }

    @Test("Quoted and completed projects cannot use this flow")
    func onlyBookedProjectsReschedule() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 3)
        let completed = TestCalendar.project(status: .completed, start: "2026-08-31", duration: 3)
        #expect(quoted.canReschedule == false)
        #expect(completed.canReschedule == false)
        #expect(alternatives(quoted).isEmpty)
        #expect(alternatives(completed).isEmpty)
    }

    @Test("Weekend start snaps forward for a manual date")
    func weekendManualDateSnapsToMonday() throws {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let preview = try #require(planner().preview(start: TestCalendar.date("2026-09-05"), duration: 3))
        #expect(isos(preview) == ["2026-09-07", "2026-09-08", "2026-09-09"])
        guard case .allowed = planner().evaluate(start: TestCalendar.date("2026-09-05"), project: project, among: [project]) else {
            Issue.record("Saturday should snap to the next working days")
            return
        }
    }
}

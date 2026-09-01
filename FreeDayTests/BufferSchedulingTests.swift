import Foundation
import SwiftData
@testable import FreeDay
import Testing

struct BufferSchedulingTests {
    private let engine = TestCalendar.engine
    private let presentation = CalendarPresentation(engine: TestCalendar.engine)
    private let now = TestCalendar.date("2026-08-31")

    @Test("1. Default buffer is 0")
    func defaultBufferIsZero() {
        let snapshot = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        #expect(snapshot.bufferInWorkingDays == 0)
        let project = Project(
            projectName: "Job",
            customerName: "Customer",
            status: .booked,
            startDate: now,
            durationInWorkingDays: 3
        )
        #expect(project.bufferInWorkingDays == 0)
    }

    @Test("2. Existing project without buffer behaves unchanged")
    func zeroBufferMatchesLegacyOccupancy() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        #expect(engine.jobDates(for: project).map(TestCalendar.iso) == [
            "2026-08-31", "2026-09-01", "2026-09-02"
        ])
        #expect(engine.bufferDates(for: project).isEmpty)
        #expect(
            engine.occupiedDates(from: [project]).map(TestCalendar.iso).sorted()
                == ["2026-08-31", "2026-09-01", "2026-09-02"]
        )
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .free)
    }

    @Test("3. Add 1-day buffer occupies the next working day")
    func oneDayBuffer() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        #expect(engine.jobDates(for: project).map(TestCalendar.iso) == [
            "2026-08-31", "2026-09-01", "2026-09-02"
        ])
        #expect(engine.bufferDates(for: project).map(TestCalendar.iso) == ["2026-09-03"])
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .booked)
        #expect(engine.availability(on: TestCalendar.date("2026-09-04"), projects: [project]) == .free)
    }

    @Test("4. Multiple buffer days occupy consecutive working days")
    func multipleBufferDays() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1, buffer: 3)
        #expect(engine.jobDates(for: project).map(TestCalendar.iso) == ["2026-08-31"])
        #expect(engine.bufferDates(for: project).map(TestCalendar.iso) == [
            "2026-09-01", "2026-09-02", "2026-09-03"
        ])
    }

    @Test("5. Remove buffer frees the day")
    func removingBufferFreesTheDay() {
        var project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .booked)
        project.bufferInWorkingDays = 0
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .free)
        #expect(engine.occupiedDates(from: [project]).map(TestCalendar.iso).sorted() == [
            "2026-08-31", "2026-09-01", "2026-09-02"
        ])
    }

    @Test("6. Buffer persists after relaunch")
    func bufferPersists() throws {
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
                durationInWorkingDays: 3,
                bufferInWorkingDays: 2
            )
        )
        try write.save()

        let read = ModelContext(container)
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        let reloaded = try #require(try read.fetch(descriptor).first)
        #expect(reloaded.bufferInWorkingDays == 2)
        #expect(reloaded.durationInWorkingDays == 3)
        #expect(engine.bufferDates(for: reloaded.snapshot).map(TestCalendar.iso) == [
            "2026-09-03", "2026-09-04"
        ])
    }

    @Test("7. Buffer uses working days only")
    func bufferSkipsWeekend() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2, buffer: 1)
        #expect(engine.jobDates(for: project).map(TestCalendar.iso) == ["2026-09-03", "2026-09-04"])
        #expect(engine.bufferDates(for: project).map(TestCalendar.iso) == ["2026-09-07"])
        #expect(engine.availability(on: TestCalendar.date("2026-09-05"), projects: [project]) == .nonWorking)
        #expect(engine.availability(on: TestCalendar.date("2026-09-06"), projects: [project]) == .nonWorking)
    }

    @Test("8. Friday job plus Monday buffer")
    func fridayJobMondayBuffer() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 1)
        #expect(engine.jobDates(for: project).map(TestCalendar.iso) == ["2026-09-04"])
        #expect(engine.bufferDates(for: project).map(TestCalendar.iso) == ["2026-09-07"])
    }

    @Test("9. Friday job plus multiple buffer days")
    func fridayJobMultipleBufferDays() {
        let project = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 2)
        #expect(engine.bufferDates(for: project).map(TestCalendar.iso) == ["2026-09-07", "2026-09-08"])
    }

    @Test("10-11. Find Free Days skips buffer days")
    func findFreeDaysRespectsBuffer() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let oneDay = engine.findFreeSlots(
            duration: 1,
            from: now,
            projects: [project],
            resultLimit: 1
        )
        #expect(oneDay.first.map { TestCalendar.iso($0.start) } == "2026-09-04")

        let threeDay = engine.findFreeSlots(
            duration: 3,
            from: now,
            projects: [project],
            resultLimit: 1
        )
        #expect(threeDay.first.map { $0.workingDates.map(TestCalendar.iso) } == [
            "2026-09-04", "2026-09-07", "2026-09-08"
        ])
    }

    @Test("12. Quoted project buffer does not block")
    func quotedBufferDoesNotBlock() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 3, buffer: 2)
        #expect(engine.occupiedDates(from: [quoted]).isEmpty)
        #expect(engine.bufferDates(for: quoted).isEmpty)
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [quoted]) == .free)
        let week = presentation.week(containing: now, projects: [quoted], now: now)
        #expect(week.day(iso: "2026-09-03")?.kind == .free)
    }

    @Test("13. Completed project buffer does not block")
    func completedBufferDoesNotBlock() {
        let done = TestCalendar.project(status: .completed, start: "2026-08-31", duration: 3, buffer: 2)
        #expect(engine.occupiedDates(from: [done]).isEmpty)
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [done]) == .free)
    }

    @Test("14. Booked project buffer blocks")
    func bookedBufferBlocks() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .booked)
    }

    @Test("15-16. Actual job dates do not include buffer")
    func jobFinishExcludesBuffer() {
        let project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let job = engine.jobDates(for: project)
        #expect(job.last.map(TestCalendar.iso) == "2026-09-02")
        #expect(!job.map(TestCalendar.iso).contains("2026-09-03"))
    }

    @Test("17. Calendar distinguishes BOOKED from BUFFER")
    func calendarShowsBufferKind() {
        let project = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let week = presentation.week(containing: now, projects: [project], now: now)
        #expect(week.day(iso: "2026-08-31")?.kind == .booked)
        #expect(week.day(iso: "2026-09-01")?.kind == .booked)
        #expect(week.day(iso: "2026-09-02")?.kind == .booked)
        #expect(week.day(iso: "2026-09-03")?.kind == .buffer)
        #expect(week.day(iso: "2026-09-03")?.kind.badgeTitle == "Buffer")
        #expect(week.day(iso: "2026-09-03")?.spokenLabel(fullDate: "Thursday 3 September") == "Thursday 3 September. Reserved buffer day.")
        #expect(week.day(iso: "2026-09-04")?.kind == .free)
        #expect(week.day(iso: "2026-09-05")?.kind == .nonWorking)
    }

    @Test("18. Buffer day conflict with another project is rejected")
    func startOnBufferDayIsRejected() {
        let existing = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-03"),
            duration: 1,
            projects: [existing]
        )
        guard case .conflict = validation else {
            Issue.record("Starting on a buffer day must conflict")
            return
        }
    }

    @Test("19. Project conflicts with another project’s buffer is rejected")
    func jobOverlappingBufferIsRejected() {
        let existing = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-03"),
            duration: 3,
            projects: [existing]
        )
        guard case .conflict = validation else {
            Issue.record("A job must not overlap another project's buffer")
            return
        }
    }

    @Test("20. Buffer overlapping another buffer is rejected")
    func buffersMustNotOverlap() {
        let existing = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-02"),
            duration: 1,
            projects: [existing],
            buffer: 1
        )
        guard case .conflict = validation else {
            Issue.record("Two buffers must not occupy the same day")
            return
        }
    }

    @Test("Example B: job after another project's buffer is allowed")
    func startAfterBufferIsAllowed() {
        let existing = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-04"),
            duration: 1,
            projects: [existing]
        )
        guard case .valid(let dates) = validation else {
            Issue.record("Friday after a Thursday buffer must be free")
            return
        }
        #expect(dates.map(TestCalendar.iso) == ["2026-09-04"])
    }

    @Test("Example C: Monday start after Friday job plus Monday buffer is rejected")
    func weekendDoesNotCreateAGap() {
        let existing = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2, buffer: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-07"),
            duration: 1,
            projects: [existing]
        )
        guard case .conflict = validation else {
            Issue.record("Monday buffer must still block")
            return
        }
    }

    @Test("21-22. Rescheduling preserves and moves buffer")
    func rescheduleMovesBuffer() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let planner = ReschedulePlanner(engine: engine)
        let decision = planner.evaluate(
            start: TestCalendar.date("2026-09-04"),
            project: moving,
            among: [moving]
        )
        guard case .allowed(let dates) = decision else {
            Issue.record("Friday start should be allowed when excluding the moving job")
            return
        }
        #expect(dates.map(TestCalendar.iso) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        var moved = moving
        moved.startDate = TestCalendar.date("2026-09-04")
        #expect(moved.bufferInWorkingDays == 1)
        #expect(engine.jobDates(for: moved).map(TestCalendar.iso) == [
            "2026-09-04", "2026-09-07", "2026-09-08"
        ])
        #expect(engine.bufferDates(for: moved).map(TestCalendar.iso) == ["2026-09-09"])
    }

    @Test("23. Rescheduling excludes its own old buffer")
    func rescheduleExcludesOwnOldBuffer() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let planner = ReschedulePlanner(engine: engine)
        let thursday = planner.evaluate(
            start: TestCalendar.date("2026-09-03"),
            project: moving,
            among: [moving]
        )
        guard case .allowed = thursday else {
            Issue.record("A project must be able to reuse its own old buffer day")
            return
        }
        let alternatives = planner.alternatives(for: moving, among: [moving], now: now)
        #expect(!alternatives.slots.isEmpty)
    }

    @Test("24. Other projects’ buffers still block rescheduling")
    func otherBuffersBlockReschedule() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let other = TestCalendar.project(status: .booked, start: "2026-09-07", duration: 1, buffer: 1)
        let planner = ReschedulePlanner(engine: engine)
        let blocked = planner.evaluate(
            start: TestCalendar.date("2026-09-08"),
            project: moving,
            among: [moving, other]
        )
        guard case .blocked = blocked else {
            Issue.record("Monday buffer of the other job must block")
            return
        }
    }

    @Test("26. Changing buffer updates availability")
    func changingBufferUpdatesAvailability() {
        var project = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1, buffer: 1)
        #expect(engine.availability(on: TestCalendar.date("2026-09-01"), projects: [project]) == .booked)
        project.bufferInWorkingDays = 3
        #expect(engine.availability(on: TestCalendar.date("2026-09-03"), projects: [project]) == .booked)
        #expect(engine.availability(on: TestCalendar.date("2026-09-04"), projects: [project]) == .free)
    }

    @Test("27. Add/Edit validates the full reserved range")
    func validationIncludesBufferDays() {
        let existing = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 1)
        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-08-31"),
            duration: 3,
            projects: [existing],
            buffer: 1
        )
        guard case .conflict = validation else {
            Issue.record("A 3-day job plus Thursday buffer must conflict with a Thursday booking")
            return
        }
    }

    @Test("28. Final reschedule conflict check includes buffer")
    func rescheduleConfirmIncludesBuffer() {
        let moving = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let other = TestCalendar.project(status: .booked, start: "2026-09-09", duration: 1)
        let planner = ReschedulePlanner(engine: engine)
        let blocked = planner.evaluate(
            start: TestCalendar.date("2026-09-04"),
            project: moving,
            among: [moving, other]
        )
        guard case .blocked = blocked else {
            Issue.record("A moved job's buffer must not land on another booked day")
            return
        }
    }
}

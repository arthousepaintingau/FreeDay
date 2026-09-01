import Foundation
import SwiftData
@testable import FreeDay
import Testing

struct SpecificDateCheckTests {
    private let engine = TestCalendar.engine
    private let search = AvailabilitySearch(engine: TestCalendar.engine)
    private let today = TestCalendar.date("2026-08-31")

    private func evaluate(
        date: String,
        duration: Int,
        horizon: Int = 90,
        projects: [ProjectSnapshot] = []
    ) -> SpecificDateResult {
        SpecificDateCheck(
            requestedDate: TestCalendar.date(date),
            duration: duration,
            horizonDays: horizon
        ).evaluate(engine: engine, search: search, projects: projects)
    }

    @Test("1. Specific Date mode evaluates a requested start")
    func specificDateModeOpens() {
        let check = SpecificDateCheck(requestedDate: today, duration: 3)
        #expect(TestCalendar.iso(check.snappedStart(using: TestCalendar.working)) == "2026-08-31")
        #expect(check.duration == 3)
    }

    @Test("2. Existing Quick Check still works unchanged")
    func existingQuickCheckUnchanged() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let quick = QuickCheck(from: today, duration: 3).result(search: search, projects: [booked])
        let find = search.findSlots(duration: 3, from: today, projects: [booked])
        #expect(quick.slots.map(\.start) == find.slots.map(\.start))
    }

    @Test("3-6. Specific date with 1, 3, 5, and 30 working days")
    func durationsOneThreeFiveThirty() throws {
        for duration in [1, 3, 5, 30] {
            let result = evaluate(date: "2026-08-31", duration: duration)
            guard case .available(_, let slot) = result else {
                Issue.record("Expected available for \(duration) days")
                continue
            }
            #expect(slot.durationWorkingDays == duration)
            #expect(TestCalendar.iso(slot.start) == "2026-08-31")
        }
        let thirty = try availableSlot(evaluate(date: "2026-08-31", duration: 30))
        #expect(thirty.workingDates.count == 30)
    }

    @Test("7. Available requested date returns YES")
    func availableReturnsYes() throws {
        let result = evaluate(date: "2026-09-15", duration: 3)
        let slot = try availableSlot(result)
        #expect(result.isAvailable)
        #expect(TestCalendar.iso(slot.start) == "2026-09-15")
        #expect(TestCalendar.iso(slot.end) == "2026-09-17")
    }

    @Test("8-9. Unavailable requested date; booked project causes conflict")
    func bookedCausesConflict() throws {
        let smith = TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-09-15", duration: 3)
        let result = evaluate(date: "2026-09-15", duration: 3, projects: [smith])
        guard case .unavailable(_, let name, let next) = result else {
            Issue.record("Expected unavailable")
            return
        }
        #expect(result.isAvailable == false)
        #expect(name == "Smith House")
        let slot = try #require(next)
        #expect(TestCalendar.iso(slot.start) == "2026-09-18")
        #expect(slot.durationWorkingDays == 3)
    }

    @Test("10. Booked buffer causes conflict")
    func bufferCausesConflict() throws {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let result = evaluate(date: "2026-09-03", duration: 1, projects: [smith])
        guard case .unavailable(_, let name, let next) = result else {
            Issue.record("Expected buffer conflict")
            return
        }
        #expect(name == "Smith House")
        #expect(TestCalendar.iso(next?.start ?? .distantPast) == "2026-09-04")
    }

    @Test("11. Quoted project does not cause conflict")
    func quotedDoesNotConflict() throws {
        let quoted = TestCalendar.project(
            customer: "Quoted",
            status: .quoted,
            start: "2026-09-15",
            duration: 5,
            buffer: 2
        )
        let slot = try availableSlot(evaluate(date: "2026-09-15", duration: 3, projects: [quoted]))
        #expect(TestCalendar.iso(slot.start) == "2026-09-15")
    }

    @Test("12. Completed project does not cause conflict")
    func completedDoesNotConflict() throws {
        let done = TestCalendar.project(
            customer: "Done",
            status: .completed,
            start: "2026-09-15",
            duration: 5,
            buffer: 2
        )
        let slot = try availableSlot(evaluate(date: "2026-09-15", duration: 3, projects: [done]))
        #expect(TestCalendar.iso(slot.start) == "2026-09-15")
    }

    @Test("13. Weekend start snaps to next working day")
    func weekendSnapsToMonday() throws {
        let check = SpecificDateCheck(requestedDate: TestCalendar.date("2026-09-05"), duration: 3)
        #expect(TestCalendar.iso(check.snappedStart(using: TestCalendar.working)) == "2026-09-07")
        let slot = try availableSlot(evaluate(date: "2026-09-05", duration: 3))
        #expect(TestCalendar.iso(slot.start) == "2026-09-07")
        #expect(TestCalendar.iso(slot.end) == "2026-09-09")
    }

    @Test("14. Friday + 3 working days ends Tuesday")
    func fridayThreeDaysEndsTuesday() throws {
        let slot = try availableSlot(evaluate(date: "2026-09-04", duration: 3))
        #expect(TestCalendar.iso(slot.start) == "2026-09-04")
        #expect(TestCalendar.iso(slot.end) == "2026-09-08")
        #expect(slot.workingDates.map(TestCalendar.iso) == ["2026-09-04", "2026-09-07", "2026-09-08"])
    }

    @Test("15-16. Next available is chronological and uses AvailabilitySearch")
    func nextAvailableUsesExistingEngine() throws {
        let smith = TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-09-15", duration: 3)
        let projects = [smith]
        let result = evaluate(date: "2026-09-15", duration: 3, projects: projects)
        guard case .unavailable(_, _, let next) = result else {
            Issue.record("Expected unavailable")
            return
        }
        let engineNext = search.findSlots(
            duration: 3,
            from: TestCalendar.date("2026-09-15"),
            projects: projects
        ).next
        #expect(next?.start == engineNext?.start)
        #expect(next?.workingDates == engineNext?.workingDates)
        #expect(TestCalendar.iso(next?.start ?? .distantPast) == "2026-09-18")
    }

    @Test("17-18. Use These Dates / Use Next Available map onto Add Project prefill")
    func useDatesPrefill() throws {
        let available = try availableSlot(evaluate(date: "2026-09-15", duration: 5))
        let yesPrefill = ProjectPrefill(
            startDate: available.start,
            durationInWorkingDays: 5,
            status: .booked,
            showFitMessage: true
        )
        #expect(yesPrefill.startDate == available.start)
        #expect(yesPrefill.durationInWorkingDays == 5)
        #expect(yesPrefill.status == .booked)

        let smith = TestCalendar.project(status: .booked, start: "2026-09-15", duration: 1)
        let result = evaluate(date: "2026-09-15", duration: 3, projects: [smith])
        let next = try #require(result.slotToUse)
        #expect(TestCalendar.iso(next.start) != "2026-09-15")
        #expect(next.durationWorkingDays == 3)
        let nextPrefill = ProjectPrefill(
            startDate: next.start,
            durationInWorkingDays: 3,
            status: .booked
        )
        #expect(nextPrefill.durationInWorkingDays == 3)
        #expect(nextPrefill.status == .booked)
    }

    @Test("19-21. Check is read-only")
    @MainActor
    func checkIsReadOnly() throws {
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

        _ = evaluate(date: "2026-08-31", duration: 3, projects: [project.snapshot])
        _ = evaluate(date: "2026-09-15", duration: 1, projects: [project.snapshot])

        let fetched = try context.fetch(FetchDescriptor<Project>())
        #expect(fetched.count == 1)
        #expect(fetched[0].customerName == "Smith House")
        #expect(fetched[0].durationInWorkingDays == 3)
        #expect(fetched[0].bufferInWorkingDays == 1)
        #expect(fetched[0].status == .booked)
    }

    @Test("22-23. Existing buffers and multi-day booked projects are respected")
    func buffersAndMultiDayRespected() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        #expect(evaluate(date: "2026-09-02", duration: 1, projects: [smith]).isAvailable == false)
        #expect(evaluate(date: "2026-09-03", duration: 1, projects: [smith]).isAvailable == false)
        #expect(evaluate(date: "2026-09-04", duration: 1, projects: [smith]).isAvailable)
    }

    @Test("24. Requested duration stays the same for next available")
    func durationUnchangedForNextAvailable() throws {
        let smith = TestCalendar.project(status: .booked, start: "2026-09-15", duration: 2)
        let result = evaluate(date: "2026-09-15", duration: 5, projects: [smith])
        #expect(result.slotToUse?.durationWorkingDays == 5)
    }

    @Test("Spoken labels distinguish available and unavailable")
    func spokenPersonality() {
        #expect(PersonalityCopy.yesYoureFree.contains("free"))
        #expect(PersonalityCopy.notAvailable.lowercased().contains("not available"))
        #expect(PersonalityCopy.conflictsWith("Smith House").contains("Smith House"))
    }

    @Test("Empty schedule is available")
    func emptySchedule() {
        #expect(evaluate(date: "2026-08-31", duration: 1).isAvailable)
    }

    @Test("Requested job overlaps last booked day")
    func overlapsLastBookedDay() {
        let smith = TestCalendar.project(status: .booked, start: "2026-09-01", duration: 3)
        let result = evaluate(date: "2026-08-31", duration: 3, projects: [smith])
        #expect(result.isAvailable == false)
    }

    @Test("Requested job ends on another project’s first day")
    func endsOnNextProjectStart() {
        let smith = TestCalendar.project(status: .booked, start: "2026-09-02", duration: 1)
        #expect(evaluate(date: "2026-08-31", duration: 3, projects: [smith]).isAvailable == false)
        #expect(evaluate(date: "2026-08-31", duration: 2, projects: [smith]).isAvailable)
    }

    @Test("No available slot within the normal horizon")
    func noSlotWithinHorizon() {
        let wall = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 80)
        let result = evaluate(date: "2026-08-31", duration: 3, horizon: 90, projects: [wall])
        guard case .unavailable(_, _, let next) = result else {
            Issue.record("Expected unavailable")
            return
        }
        #expect(next == nil)
        let further = evaluate(date: "2026-08-31", duration: 3, horizon: 180, projects: [wall])
        #expect(further.slotToUse != nil)
    }

    private func availableSlot(_ result: SpecificDateResult) throws -> FreeSlot {
        guard case .available(_, let slot) = result else {
            Issue.record("Expected available result")
            throw TestFailure()
        }
        return slot
    }
}

private struct TestFailure: Error {}

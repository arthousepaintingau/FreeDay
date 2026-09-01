import Foundation
@testable import FreeDay
import Testing

struct AvailabilitySearchTests {
    private let calendar = TestCalendar.working
    private let engine = TestCalendar.engine

    private func slots(
        duration: Int,
        from: String = "2026-08-31",
        projects: [ProjectSnapshot] = [],
        horizon: Int = 90,
        limit: Int = 5
    ) -> AvailabilitySearchResult {
        AvailabilitySearch(
            engine: engine,
            options: AvailabilitySearchOptions(calendarDayHorizon: horizon, resultLimit: limit)
        ).findSlots(
            duration: duration,
            from: TestCalendar.date(from),
            projects: projects
        )
    }

    private func isos(_ slot: FreeSlot) -> [String] {
        slot.workingDates.map(TestCalendar.iso)
    }

    @Test("Empty schedule → 1-day slot")
    func emptyScheduleOneDay() throws {
        let result = slots(duration: 1)
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-08-31"])
        #expect(TestCalendar.iso(next.start) == "2026-08-31")
        #expect(TestCalendar.iso(next.end) == "2026-08-31")
        #expect(next.durationWorkingDays == 1)
    }

    @Test("Empty schedule → 3-day slot")
    func emptyScheduleThreeDays() throws {
        let result = slots(duration: 3)
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-08-31", "2026-09-01", "2026-09-02"])
        #expect(TestCalendar.iso(next.start) == "2026-08-31")
        #expect(TestCalendar.iso(next.end) == "2026-09-02")
        #expect(next.durationWorkingDays == 3)
    }

    @Test("Empty schedule → 5-day slot")
    func emptyScheduleFiveDays() throws {
        let result = slots(duration: 5)
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"])
        #expect(TestCalendar.iso(next.end) == "2026-09-04")
        #expect(next.durationWorkingDays == 5)
    }

    @Test("Existing 1-day booked project is skipped")
    func existingOneDayBooked() throws {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        let result = slots(duration: 3, projects: [booked])
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-01", "2026-09-02", "2026-09-03"])
    }

    @Test("Existing 3-day booked project is skipped")
    func existingThreeDayBooked() throws {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let result = slots(duration: 3, projects: [booked])
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-03", "2026-09-04", "2026-09-07"])
    }

    @Test("Multiple booked projects leave only true gaps")
    func multipleBookedProjects() {
        let first = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 2)
        let second = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2)
        let result = slots(duration: 2, projects: [first, second])
        #expect(result.slots.map { TestCalendar.iso($0.start) } == [
            "2026-09-07",
            "2026-09-09",
            "2026-09-11",
            "2026-09-15",
            "2026-09-17"
        ])
    }

    @Test("Weekend crossing never includes Saturday or Sunday")
    func weekendCrossing() throws {
        let result = slots(duration: 3, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        #expect(!isos(next).contains("2026-09-05"))
        #expect(!isos(next).contains("2026-09-06"))
    }

    @Test("Quoted project does not block availability")
    func quotedDoesNotBlock() throws {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 5)
        let result = slots(duration: 3, projects: [quoted])
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-08-31")
    }

    @Test("Completed project does not block availability")
    func completedDoesNotBlock() throws {
        let completed = TestCalendar.project(status: .completed, start: "2026-08-31", duration: 5)
        let result = slots(duration: 3, projects: [completed])
        let next = try #require(result.next)
        #expect(TestCalendar.iso(next.start) == "2026-08-31")
        #expect(engine.occupiedDates(from: [completed]).isEmpty)
    }

    @Test("Earliest slot is returned first")
    func earliestSlotFirst() {
        let booked = TestCalendar.project(status: .booked, start: "2026-09-01", duration: 1)
        let result = slots(duration: 1, projects: [booked])
        #expect(result.slots.map { TestCalendar.iso($0.start) }.first == "2026-08-31")
        let starts = result.slots.map { TestCalendar.iso($0.start) }
        #expect(starts == starts.sorted())
    }

    @Test("Multiple available slots are returned in chronological order")
    func slotsAreChronological() {
        let result = slots(duration: 3)
        let starts = result.slots.map { TestCalendar.iso($0.start) }
        #expect(starts == ["2026-08-31", "2026-09-03", "2026-09-08", "2026-09-11", "2026-09-16"])
        #expect(starts == starts.sorted())
    }

    @Test("Exact requested duration is returned")
    func exactDuration() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 2)
        let result = slots(duration: 4, projects: [booked])
        #expect(!result.slots.isEmpty)
        #expect(result.slots.allSatisfy { $0.durationWorkingDays == 4 })
        #expect(result.slots.allSatisfy { $0.workingDates.count == 4 })
    }

    @Test("No slot within 90 days")
    func noSlotWithinHorizon() {
        let from = TestCalendar.date("2026-08-31")
        let through = calendar.date(byAddingDays: 90, to: from)
        let window = calendar.workingDays(from: from, through: through)
        let wall = TestCalendar.project(status: .booked, start: "2026-08-31", duration: window.count)
        let result = slots(duration: 3, projects: [wall], horizon: 90)
        #expect(result.isEmpty)
        #expect(result.horizonDays == 90)
        #expect(result.next == nil)
    }

    @Test("Slot never overlaps booked work")
    func neverOverlapsBookedWork() {
        let booked = TestCalendar.project(status: .booked, start: "2026-09-02", duration: 1)
        let occupied = engine.occupiedDates(from: [booked])
        let result = slots(duration: 3, projects: [booked])
        #expect(!result.slots.isEmpty)
        for slot in result.slots {
            #expect(Set(slot.workingDates).isDisjoint(with: occupied))
            #expect(!isos(slot).contains("2026-09-02"))
        }
    }

    @Test("Start date and end date match the working-day range")
    func startAndEndDates() throws {
        let result = slots(duration: 3, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(next.start == next.workingDates.first)
        #expect(next.end == next.workingDates.last)
        #expect(TestCalendar.iso(next.start) == "2026-09-04")
        #expect(TestCalendar.iso(next.end) == "2026-09-08")
    }

    @Test("Friday-to-Monday calculations skip the weekend")
    func fridayToMonday() throws {
        let result = slots(duration: 2, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-04", "2026-09-07"])
        #expect(calendar.isWorkingDay(next.start))
        #expect(calendar.isWorkingDay(next.end))
    }

    @Test("1-day job on Friday stays on Friday")
    func oneDayFriday() throws {
        let result = slots(duration: 1, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-04"])
        #expect(!calendar.isWorkingDay(TestCalendar.date("2026-09-05")))
    }

    @Test("3-day job starting Friday")
    func threeDayStartingFriday() throws {
        let result = slots(duration: 3, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-04", "2026-09-07", "2026-09-08"])
    }

    @Test("5-day job crossing a weekend")
    func fiveDayCrossingWeekend() throws {
        let result = slots(duration: 5, from: "2026-09-04")
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-04", "2026-09-07", "2026-09-08", "2026-09-09", "2026-09-10"])
        #expect(!isos(next).contains("2026-09-05"))
        #expect(!isos(next).contains("2026-09-06"))
        #expect(next.durationWorkingDays == 5)
    }

    @Test("Multiple gaps between booked projects")
    func multipleGaps() {
        let first = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 2)
        let second = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2)
        let result = slots(duration: 1, projects: [first, second])
        #expect(result.slots.map { TestCalendar.iso($0.start) } == [
            "2026-09-02",
            "2026-09-07",
            "2026-09-08",
            "2026-09-09",
            "2026-09-10"
        ])
    }

    @Test("Wed–Fri is not suggested when Wednesday or Friday is booked")
    func conflictSafetyAcrossPartialWeek() throws {
        let projectA = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let projectB = TestCalendar.project(status: .booked, start: "2026-09-04", duration: 2)
        let result = slots(duration: 3, projects: [projectA, projectB])
        let occupied = engine.occupiedDates(from: [projectA, projectB])
        #expect(occupied.contains(TestCalendar.date("2026-09-02")))
        #expect(occupied.contains(TestCalendar.date("2026-09-04")))
        for slot in result.slots {
            #expect(Set(slot.workingDates).isDisjoint(with: occupied))
            #expect(!isos(slot).contains("2026-09-02"))
            #expect(!isos(slot).contains("2026-09-04"))
        }
        let next = try #require(result.next)
        #expect(isos(next) == ["2026-09-08", "2026-09-09", "2026-09-10"])
    }

    @Test("Returned slots never include weekend days")
    func noWeekendDaysInSlots() {
        let result = slots(duration: 5, from: "2026-09-04")
        for slot in result.slots {
            #expect(slot.workingDates.allSatisfy(calendar.isWorkingDay))
        }
    }
}

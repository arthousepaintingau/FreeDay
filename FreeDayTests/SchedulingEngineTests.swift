import Foundation
@testable import FreeDay
import Testing

struct TestCalendar {
    static let working = WorkingCalendar.australiaDefault
    static let engine = SchedulingEngine(workingCalendar: working)

    static func makeEngine(worksSaturday: Bool = false, worksSunday: Bool = false) -> SchedulingEngine {
        SchedulingEngine(
            workingCalendar: WorkingCalendar(
                settings: .australia(worksSaturday: worksSaturday, worksSunday: worksSunday)
            )
        )
    }

    static func date(_ iso: String) -> Date {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        precondition(parts.count == 3, "Expected yyyy-MM-dd")
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = working.calendar.date(from: components) else {
            preconditionFailure("Invalid date \(iso)")
        }
        return working.startOfDay(date)
    }

    static func iso(_ date: Date) -> String {
        let parts = working.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func project(
        id: UUID = UUID(),
        name: String = "Job",
        customer: String = "Customer",
        status: ProjectStatus,
        start: String?,
        duration: Int,
        buffer: Int = 0
    ) -> ProjectSnapshot {
        ProjectSnapshot(
            id: id,
            projectName: name,
            customerName: customer,
            phoneNumber: nil,
            address: nil,
            notes: nil,
            status: status,
            startDate: start.map(date),
            durationInWorkingDays: duration,
            bufferInWorkingDays: buffer,
            createdDate: date("2026-08-01"),
            completedDate: status == .completed ? date("2026-08-20") : nil
        )
    }
}

struct SchedulingEngineTests {
    private let engine = TestCalendar.engine

    @Test("1-day project occupies a single working day")
    func oneDayProject() {
        let dates = engine.workingDates(start: TestCalendar.date("2026-08-31"), duration: 1)
        #expect(dates.map(TestCalendar.iso) == ["2026-08-31"])
    }

    @Test("3-day project occupies three consecutive working days")
    func threeDayProject() {
        let dates = engine.workingDates(start: TestCalendar.date("2026-08-31"), duration: 3)
        #expect(dates.map(TestCalendar.iso) == ["2026-08-31", "2026-09-01", "2026-09-02"])
    }

    @Test("5-day project occupies a full working week")
    func fiveDayProject() {
        let dates = engine.workingDates(start: TestCalendar.date("2026-08-31"), duration: 5)
        #expect(dates.map(TestCalendar.iso) == [
            "2026-08-31",
            "2026-09-01",
            "2026-09-02",
            "2026-09-03",
            "2026-09-04"
        ])
    }

    @Test("Weekend days never count toward duration")
    func weekendCrossing() {
        let dates = engine.workingDates(start: TestCalendar.date("2026-09-04"), duration: 3)
        #expect(dates.map(TestCalendar.iso) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        #expect(!dates.contains(where: { TestCalendar.iso($0) == "2026-09-05" }))
        #expect(!dates.contains(where: { TestCalendar.iso($0) == "2026-09-06" }))
    }

    @Test("Start date on a weekend snaps to the next working day")
    func weekendStartSnapsForward() {
        let dates = engine.workingDates(start: TestCalendar.date("2026-09-05"), duration: 2)
        #expect(dates.map(TestCalendar.iso) == ["2026-09-07", "2026-09-08"])
    }

    @Test("Existing booked project is skipped when finding free days")
    func existingBookedProject() {
        let booked = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 3)
        let slots = engine.findFreeSlots(
            duration: 3,
            from: TestCalendar.date("2026-08-31"),
            projects: [booked],
            resultLimit: 3,
            workingDayHorizon: 15
        )
        #expect(slots.map { TestCalendar.iso($0.start) } == ["2026-09-03", "2026-09-08", "2026-09-11"])
        #expect(slots[0].workingDates.map(TestCalendar.iso) == ["2026-09-03", "2026-09-04", "2026-09-07"])
    }

    @Test("Multiple booked projects leave only true gaps")
    func multipleBookedProjects() {
        let first = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 2)
        let second = TestCalendar.project(status: .booked, start: "2026-09-03", duration: 2)
        let slots = engine.findFreeSlots(
            duration: 2,
            from: TestCalendar.date("2026-08-31"),
            projects: [first, second],
            resultLimit: 3,
            workingDayHorizon: 12
        )
        #expect(slots.map { TestCalendar.iso($0.start) } == ["2026-09-07", "2026-09-09", "2026-09-11"])
    }

    @Test("No available slot when the horizon is fully booked")
    func noAvailableSlot() {
        let wall = TestCalendar.project(status: .booked, start: "2026-08-31", duration: 400)
        let slots = engine.findFreeSlots(
            duration: 3,
            from: TestCalendar.date("2026-08-31"),
            projects: [wall],
            resultLimit: 5,
            workingDayHorizon: 10
        )
        #expect(slots.isEmpty)

        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-09-01"),
            duration: 1,
            projects: [wall]
        )
        guard case .conflict(let suggested) = validation else {
            Issue.record("Expected a conflict")
            return
        }
        #expect(suggested == nil)
    }

    @Test("Rescheduling excludes the moving project and still detects other conflicts")
    func rescheduling() {
        let movingID = UUID()
        let moving = TestCalendar.project(id: movingID, status: .booked, start: "2026-08-31", duration: 3)
        let other = TestCalendar.project(status: .booked, start: "2026-09-07", duration: 2)

        let keepSame = engine.validateBooking(
            start: TestCalendar.date("2026-08-31"),
            duration: 3,
            projects: [moving, other],
            excluding: movingID
        )
        guard case .valid(let kept) = keepSame else {
            Issue.record("A project must be able to keep its own dates")
            return
        }
        #expect(kept.map(TestCalendar.iso) == ["2026-08-31", "2026-09-01", "2026-09-02"])

        let intoOther = engine.validateBooking(
            start: TestCalendar.date("2026-09-07"),
            duration: 3,
            projects: [moving, other],
            excluding: movingID
        )
        guard case .conflict(let suggested) = intoOther else {
            Issue.record("Expected a conflict against the other booked job")
            return
        }
        #expect(suggested.map { TestCalendar.iso($0.start) } == "2026-09-09")

        let openSlot = engine.validateBooking(
            start: TestCalendar.date("2026-09-09"),
            duration: 3,
            projects: [moving, other],
            excluding: movingID
        )
        guard case .valid(let dates) = openSlot else {
            Issue.record("Expected the later slot to be valid")
            return
        }
        #expect(dates.map(TestCalendar.iso) == ["2026-09-09", "2026-09-10", "2026-09-11"])
    }

    @Test("Quoted projects do not block availability")
    func quotedDoesNotBlock() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 5)
        #expect(engine.availability(on: TestCalendar.date("2026-08-31"), projects: [quoted]) == .tentative)

        let slots = engine.findFreeSlots(
            duration: 3,
            from: TestCalendar.date("2026-08-31"),
            projects: [quoted],
            resultLimit: 1
        )
        #expect(slots.first.map { TestCalendar.iso($0.start) } == "2026-08-31")

        let validation = engine.validateBooking(
            start: TestCalendar.date("2026-08-31"),
            duration: 3,
            projects: [quoted]
        )
        guard case .valid = validation else {
            Issue.record("Quoted work must not create a booking conflict")
            return
        }
    }

    @Test("Completed projects do not block future availability")
    func completedDoesNotBlock() {
        let completed = TestCalendar.project(status: .completed, start: "2026-08-31", duration: 5)
        #expect(engine.availability(on: TestCalendar.date("2026-08-31"), projects: [completed]) == .free)

        let slots = engine.findFreeSlots(
            duration: 3,
            from: TestCalendar.date("2026-08-31"),
            projects: [completed],
            resultLimit: 1
        )
        #expect(slots.first.map { TestCalendar.iso($0.start) } == "2026-08-31")
        #expect(engine.occupiedDates(from: [completed]).isEmpty)
    }

    @Test("Booked status wins over a quoted overlap on the same day")
    func bookedWinsOverTentative() {
        let quoted = TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 3)
        let booked = TestCalendar.project(status: .booked, start: "2026-09-01", duration: 1)
        #expect(engine.availability(on: TestCalendar.date("2026-08-31"), projects: [quoted, booked]) == .tentative)
        #expect(engine.availability(on: TestCalendar.date("2026-09-01"), projects: [quoted, booked]) == .booked)
        #expect(engine.availability(on: TestCalendar.date("2026-09-05"), projects: [quoted, booked]) == .nonWorking)
    }
}

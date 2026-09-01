import Foundation
@testable import FreeDay
import Testing

struct ComingCapacityTests {
    private let engine = TestCalendar.engine
    private let today = TestCalendar.date("2026-08-31")

    private func snapshot(
        from: String = "2026-08-31",
        projects: [ProjectSnapshot] = []
    ) -> ComingCapacity {
        ComingCapacityBuilder(engine: engine).make(
            projects: projects,
            now: TestCalendar.date(from)
        )
    }

    @Test("1. 14-day window")
    func fourteenDayWindow() {
        let result = snapshot()
        #expect(result.days.count == 14)
        #expect(TestCalendar.iso(result.start) == "2026-08-31")
        #expect(TestCalendar.iso(result.end) == "2026-09-13")
        #expect(result.days.first?.isoDate == "2026-08-31")
        #expect(result.days.last?.isoDate == "2026-09-13")
    }

    @Test("2. Correct number of working days")
    func workingDayCount() {
        let result = snapshot()
        #expect(result.workingDayCount == 10)
        #expect(result.days.filter(\.isWorkingDay).count == 10)
    }

    @Test("3. Weekends excluded from FREE count")
    func weekendsExcludedFromFree() {
        let result = snapshot()
        #expect(result.freeWorkingDays == 10)
        #expect(result.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(result.day(iso: "2026-09-06")?.kind == .nonWorking)
        #expect(result.days.filter { $0.kind == .free }.count == 10)
    }

    @Test("4-5. Booked job counts correctly, including multi-day")
    func bookedJobCountsDistinctProjects() {
        let smith = TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-08-31", duration: 3)
        let result = snapshot(projects: [smith])
        #expect(result.bookedJobs == 1)
        #expect(result.occupiedWorkingDays == 3)
        #expect(result.freeWorkingDays == 7)
        for iso in ["2026-08-31", "2026-09-01", "2026-09-02"] {
            #expect(result.day(iso: iso)?.kind == .booked)
            #expect(result.day(iso: iso)?.displayName == "Smith House")
        }
    }

    @Test("6. Booked buffer counts correctly")
    func bookedBufferCounts() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let result = snapshot(projects: [smith])
        #expect(result.bookedJobs == 1)
        #expect(result.bufferDays == 1)
        #expect(result.occupiedWorkingDays == 4)
        #expect(result.day(iso: "2026-09-03")?.kind == .buffer)
        #expect(result.day(iso: "2026-09-03")?.displayName == nil)
    }

    @Test("7-8. Quoted project and quoted buffer do not block")
    func quotedDoesNotBlock() {
        let quoted = TestCalendar.project(
            customer: "Johnson House",
            status: .quoted,
            start: "2026-08-31",
            duration: 5,
            buffer: 2
        )
        let result = snapshot(projects: [quoted])
        #expect(result.bookedJobs == 0)
        #expect(result.bufferDays == 0)
        #expect(result.freeWorkingDays == 10)
        #expect(result.day(iso: "2026-08-31")?.kind == .free)
        #expect(result.busyLevel == .light)
    }

    @Test("9-10. Completed project and completed buffer do not block")
    func completedDoesNotBlock() {
        let done = TestCalendar.project(
            customer: "Old Job",
            status: .completed,
            start: "2026-08-31",
            duration: 5,
            buffer: 2
        )
        let result = snapshot(projects: [done])
        #expect(result.bookedJobs == 0)
        #expect(result.bufferDays == 0)
        #expect(result.freeWorkingDays == 10)
        #expect(result.day(iso: "2026-08-31")?.kind == .free)
        #expect(result.busyLevel == .light)
    }

    @Test("11-13. FREE, BUFFER, and BOOKED distinction")
    func freeBufferBookedDistinction() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let result = snapshot(projects: [smith])
        #expect(result.day(iso: "2026-08-31")?.kind == .booked)
        #expect(result.day(iso: "2026-09-03")?.kind == .buffer)
        #expect(result.day(iso: "2026-09-04")?.kind == .free)
        #expect(result.day(iso: "2026-09-04")?.canUseDay == true)
        #expect(result.day(iso: "2026-08-31")?.canUseDay == false)
        #expect(result.day(iso: "2026-09-03")?.canUseDay == false)
    }

    @Test("14. Multi-day project display uses the customer name on job days only")
    func multiDayDisplay() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let result = snapshot(projects: [smith])
        #expect(result.days.filter { $0.displayName == "Smith House" }.map(\.isoDate) == [
            "2026-08-31",
            "2026-09-01",
            "2026-09-02"
        ])
    }

    @Test("15-17. Distinct jobs, buffer days, no double counting")
    func noDoubleCounting() {
        let first = TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-08-31", duration: 3, buffer: 1)
        let second = TestCalendar.project(customer: "Jones", status: .booked, start: "2026-09-07", duration: 1)
        let result = snapshot(projects: [first, second])
        #expect(result.bookedJobs == 2)
        #expect(result.bufferDays == 1)
        #expect(result.occupiedWorkingDays == 5)
        #expect(result.freeWorkingDays == 5)
    }

    @Test("18. Busy Meter LIGHT")
    func busyMeterLight() {
        let empty = snapshot()
        #expect(empty.occupancyPercent == 0)
        #expect(empty.busyLevel == .light)
        #expect(empty.personality == PersonalityCopy.plentyOfRoom)

        let light = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 2)
        ])
        #expect(light.occupancyPercent == 20)
        #expect(light.busyLevel == .light)
    }

    @Test("19. Busy Meter BALANCED")
    func busyMeterBalanced() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 4)
        ])
        #expect(result.occupancyPercent == 40)
        #expect(result.busyLevel == .balanced)
        #expect(result.personality == PersonalityCopy.gotSomeSpace)
    }

    @Test("20. Busy Meter BUSY")
    func busyMeterBusy() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 6)
        ])
        #expect(result.occupancyPercent == 60)
        #expect(result.busyLevel == .busy)
        #expect(result.personality == PersonalityCopy.thingsGettingBusy)
    }

    @Test("21-22. Busy Meter PACKED and personality matches")
    func busyMeterPacked() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 8)
        ])
        #expect(result.occupancyPercent == 80)
        #expect(result.busyLevel == .packed)
        #expect(result.personality == PersonalityCopy.fullyBooked)
        #expect(result.spokenBusyMeter.contains("Packed"))
        #expect(result.spokenBusyMeter.contains("80"))
    }

    @Test("23. Today is correctly identified")
    func todayIsIdentified() {
        let result = snapshot(from: "2026-08-31")
        #expect(result.day(iso: "2026-08-31")?.isToday == true)
        #expect(result.days.filter(\.isToday).count == 1)
        #expect(result.day(iso: "2026-09-01")?.isToday == false)
    }

    @Test("24. Rolling 14-day window")
    func rollingWindow() {
        let result = snapshot(from: "2026-09-02")
        #expect(TestCalendar.iso(result.start) == "2026-09-02")
        #expect(TestCalendar.iso(result.end) == "2026-09-15")
        #expect(result.day(iso: "2026-08-31") == nil)
        #expect(result.day(iso: "2026-09-02")?.isToday == true)
        #expect(result.days.count == 14)
    }

    @Test("Zero projects")
    func zeroProjects() {
        let result = snapshot()
        #expect(result.bookedJobs == 0)
        #expect(result.bufferDays == 0)
        #expect(result.freeWorkingDays == 10)
        #expect(result.busyLevel == .light)
    }

    @Test("One booked 1-day project")
    func oneDayBooked() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 1)
        ])
        #expect(result.bookedJobs == 1)
        #expect(result.occupiedWorkingDays == 1)
        #expect(result.day(iso: "2026-08-31")?.kind == .booked)
        #expect(result.day(iso: "2026-09-01")?.kind == .free)
    }

    @Test("Project crossing weekend")
    func projectCrossingWeekend() {
        let result = snapshot(projects: [
            TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-09-04", duration: 3)
        ])
        #expect(result.day(iso: "2026-09-04")?.kind == .booked)
        #expect(result.day(iso: "2026-09-05")?.kind == .nonWorking)
        #expect(result.day(iso: "2026-09-07")?.kind == .booked)
        #expect(result.day(iso: "2026-09-08")?.kind == .booked)
        #expect(result.occupiedWorkingDays == 3)
    }

    @Test("Project with buffer crossing weekend")
    func bufferCrossingWeekend() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-09-04", duration: 1, buffer: 2)
        ])
        #expect(result.day(iso: "2026-09-04")?.kind == .booked)
        #expect(result.day(iso: "2026-09-07")?.kind == .buffer)
        #expect(result.day(iso: "2026-09-08")?.kind == .buffer)
        #expect(result.bufferDays == 2)
        #expect(result.bookedJobs == 1)
        #expect(result.occupiedWorkingDays == 3)
    }

    @Test("All working days occupied")
    func allWorkingDaysOccupied() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .booked, start: "2026-08-31", duration: 10)
        ])
        #expect(result.freeWorkingDays == 0)
        #expect(result.occupiedWorkingDays == 10)
        #expect(result.busyLevel == .packed)
        #expect(result.occupancyPercent == 100)
    }

    @Test("Only quoted projects")
    func onlyQuoted() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .quoted, start: "2026-08-31", duration: 3, buffer: 2),
            TestCalendar.project(customer: "Two", status: .quoted, start: "2026-09-07", duration: 2)
        ])
        #expect(result.bookedJobs == 0)
        #expect(result.freeWorkingDays == 10)
        #expect(result.busyLevel == .light)
    }

    @Test("Only completed projects")
    func onlyCompleted() {
        let result = snapshot(projects: [
            TestCalendar.project(status: .completed, start: "2026-08-31", duration: 5, buffer: 1)
        ])
        #expect(result.bookedJobs == 0)
        #expect(result.bufferDays == 0)
        #expect(result.busyLevel == .light)
    }

    @Test("Booked + quoted mixed")
    func bookedAndQuotedMixed() {
        let result = snapshot(projects: [
            TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-08-31", duration: 1),
            TestCalendar.project(customer: "Quoted", status: .quoted, start: "2026-09-01", duration: 5, buffer: 2)
        ])
        #expect(result.bookedJobs == 1)
        #expect(result.occupiedWorkingDays == 1)
        #expect(result.day(iso: "2026-09-01")?.kind == .free)
    }

    @Test("Booked + completed mixed")
    func bookedAndCompletedMixed() {
        let result = snapshot(projects: [
            TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-09-07", duration: 1),
            TestCalendar.project(customer: "Done", status: .completed, start: "2026-08-31", duration: 3, buffer: 1)
        ])
        #expect(result.bookedJobs == 1)
        #expect(result.bufferDays == 0)
        #expect(result.day(iso: "2026-08-31")?.kind == .free)
        #expect(result.day(iso: "2026-09-07")?.kind == .booked)
    }

    @Test("Booked + buffer + quoted")
    func bookedBufferQuoted() {
        let result = snapshot(projects: [
            TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-08-31", duration: 3, buffer: 1),
            TestCalendar.project(customer: "Quoted", status: .quoted, start: "2026-09-04", duration: 2, buffer: 2)
        ])
        #expect(result.bookedJobs == 1)
        #expect(result.bufferDays == 1)
        #expect(result.day(iso: "2026-09-04")?.kind == .free)
    }

    @Test("Multiple booked projects")
    func multipleBookedProjects() {
        let result = snapshot(projects: [
            TestCalendar.project(customer: "Smith House", status: .booked, start: "2026-08-31", duration: 2),
            TestCalendar.project(customer: "Jones", status: .booked, start: "2026-09-03", duration: 2),
            TestCalendar.project(customer: "Lee", status: .booked, start: "2026-09-08", duration: 1)
        ])
        #expect(result.bookedJobs == 3)
        #expect(result.occupiedWorkingDays == 5)
    }

    @Test("This week and next week sections")
    func weekSections() {
        let result = snapshot()
        #expect(result.sections.count == 2)
        #expect(result.sections[0].kind == .thisWeek)
        #expect(result.sections[1].kind == .nextWeek)
        #expect(result.sections[0].days.count == 7)
        #expect(result.sections[1].days.count == 7)
    }

    @Test("Spoken labels distinguish booked, buffer, and free")
    func spokenLabels() {
        let smith = TestCalendar.project(
            customer: "Smith House",
            status: .booked,
            start: "2026-08-31",
            duration: 3,
            buffer: 1
        )
        let result = snapshot(projects: [smith])
        let formatters = DateFormatters(workingCalendar: TestCalendar.working)
        let monday = result.day(iso: "2026-08-31")!
        #expect(monday.spokenLabel(fullDate: formatters.fullDate(monday.date)).contains("Booked"))
        #expect(monday.spokenLabel(fullDate: formatters.fullDate(monday.date)).contains("Smith House"))
        let thursday = result.day(iso: "2026-09-03")!
        #expect(thursday.spokenLabel(fullDate: formatters.fullDate(thursday.date)).contains("Reserved buffer day"))
        let friday = result.day(iso: "2026-09-04")!
        #expect(friday.spokenLabel(fullDate: formatters.fullDate(friday.date)).contains("Free working day"))
    }
}

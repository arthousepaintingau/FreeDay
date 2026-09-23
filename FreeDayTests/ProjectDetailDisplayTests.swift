import Foundation
import SwiftData
@testable import FreeDay
import Testing

struct ProjectDetailDisplayTests {
    private let engine = TestCalendar.engine

    @Test("Saturday start displays from the next working day")
    func saturdayStartDisplaysMonday() {
        let stored = TestCalendar.date("2026-09-05")
        let schedule = ProjectDetailDisplay.workingSchedule(
            startDate: stored,
            durationInWorkingDays: 3,
            engine: engine
        )

        #expect(TestCalendar.iso(stored) == "2026-09-05")
        #expect(!engine.workingCalendar.isWorkingDay(stored))
        #expect(schedule.map(TestCalendar.iso) == ["2026-09-07", "2026-09-08", "2026-09-09"])
        #expect(schedule.first.map(TestCalendar.iso) == "2026-09-07")
        #expect(engine.workingCalendar.isWorkingDay(schedule[0]))
    }

    @Test("Sunday start displays from the next working day")
    func sundayStartDisplaysMonday() {
        let stored = TestCalendar.date("2026-09-06")
        let schedule = ProjectDetailDisplay.workingSchedule(
            startDate: stored,
            durationInWorkingDays: 3,
            engine: engine
        )

        #expect(TestCalendar.iso(stored) == "2026-09-06")
        #expect(!engine.workingCalendar.isWorkingDay(stored))
        #expect(schedule.map(TestCalendar.iso) == ["2026-09-07", "2026-09-08", "2026-09-09"])
        #expect(schedule.first.map(TestCalendar.iso) == "2026-09-07")
    }

    @Test("Working-day start keeps the stored first day")
    func weekdayStartUnchanged() {
        let stored = TestCalendar.date("2026-09-04")
        let schedule = ProjectDetailDisplay.workingSchedule(
            startDate: stored,
            durationInWorkingDays: 3,
            engine: engine
        )

        #expect(engine.workingCalendar.isWorkingDay(stored))
        #expect(schedule.map(TestCalendar.iso) == ["2026-09-04", "2026-09-07", "2026-09-08"])
        #expect(schedule.first.map(TestCalendar.iso) == "2026-09-04")
    }

    @Test("Quoted and completed weekend starts use the same display snap")
    func quotedAndCompletedWeekendStartsSnapForDisplay() {
        let saturday = TestCalendar.date("2026-09-05")
        for status in [ProjectStatus.quoted, .completed] {
            let project = TestCalendar.project(status: status, start: "2026-09-05", duration: 2)
            let schedule = ProjectDetailDisplay.workingSchedule(
                startDate: project.startDate,
                durationInWorkingDays: project.durationInWorkingDays,
                engine: engine
            )
            #expect(project.startDate == saturday)
            #expect(schedule.map(TestCalendar.iso) == ["2026-09-07", "2026-09-08"])
        }
    }
}

@Suite(.serialized)
@MainActor
struct ProjectDetailDisplayPersistenceTests {
    @Test("Displaying a weekend start does not change the stored start date")
    func displayDoesNotRewriteStoredStartDate() throws {
        let container = try Persistence.inMemoryContainer()
        let context = ModelContext(container)
        let saturday = TestCalendar.date("2026-09-05")
        let project = Project(
            projectName: "Weekend start",
            customerName: "Harbour House",
            status: .booked,
            startDate: saturday,
            durationInWorkingDays: 2
        )
        context.insert(project)
        try context.save()

        let schedule = ProjectDetailDisplay.workingSchedule(
            startDate: project.startDate,
            durationInWorkingDays: project.durationInWorkingDays,
            engine: TestCalendar.engine
        )

        #expect(project.startDate == saturday)
        #expect(TestCalendar.iso(project.startDate!) == "2026-09-05")
        #expect(schedule.map(TestCalendar.iso) == ["2026-09-07", "2026-09-08"])
        #expect(schedule.first != project.startDate)

        try context.save()
        let fetched = try context.fetch(FetchDescriptor<Project>())
        #expect(fetched.count == 1)
        #expect(fetched[0].startDate == saturday)
        #expect(TestCalendar.iso(fetched[0].startDate!) == "2026-09-05")
    }
}

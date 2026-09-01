import Foundation
import SwiftData
@testable import FreeDay
import Testing

@Suite(.serialized)
@MainActor
struct ProjectPersistenceTests {
    private let engine = TestCalendar.engine

    private func makeContainer() throws -> ModelContainer {
        try Persistence.inMemoryContainer()
    }

    @Test("Creating a project stores the required fields")
    func creatingAProject() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let project = Project(
            projectName: "Interior painting",
            customerName: "Smith House",
            status: .quoted,
            durationInWorkingDays: 3
        )
        context.insert(project)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Project>())
        #expect(fetched.count == 1)
        #expect(fetched[0].projectName == "Interior painting")
        #expect(fetched[0].customerName == "Smith House")
        #expect(fetched[0].status == .quoted)
        #expect(fetched[0].startDate == nil)
        #expect(fetched[0].durationInWorkingDays == 3)
        #expect(fetched[0].completedDate == nil)
    }

    @Test("Saving and retrieving a project from a new context")
    func savingAndRetrieving() throws {
        let container = try makeContainer()
        let write = ModelContext(container)
        let id = UUID()
        write.insert(
            Project(
                id: id,
                projectName: "Exterior walls",
                customerName: "Jones",
                phoneNumber: "0400 000 000",
                address: "12 Harbour St",
                notes: "Bring extra drop sheets",
                status: .booked,
                startDate: TestCalendar.date("2026-08-31"),
                durationInWorkingDays: 2
            )
        )
        try write.save()

        let read = ModelContext(container)
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.id == id }
        )
        let fetched = try read.fetch(descriptor)
        #expect(fetched.count == 1)
        let project = try #require(fetched.first)
        #expect(project.projectName == "Exterior walls")
        #expect(project.customerName == "Jones")
        #expect(project.phoneNumber == "0400 000 000")
        #expect(project.address == "12 Harbour St")
        #expect(project.notes == "Bring extra drop sheets")
        #expect(project.status == .booked)
        #expect(project.startDate == TestCalendar.date("2026-08-31"))
        #expect(project.durationInWorkingDays == 2)
    }

    @Test("Quoted project can be stored without a start date")
    func quotedWithoutStartDatePersists() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(
            Project(
                projectName: "Quote only",
                customerName: "Taylor",
                status: .quoted,
                durationInWorkingDays: 4
            )
        )
        try context.save()
        let project = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        #expect(project.startDate == nil)
        #expect(!project.snapshot.blocksAvailability)
        #expect(engine.occupiedDates(from: [project.snapshot]).isEmpty)
    }

    @Test("1-day booked project occupies a single working day")
    func oneDayProject() throws {
        let dates = storedSchedule(duration: 1, start: "2026-08-31")
        #expect(dates == ["2026-08-31"])
    }

    @Test("3-day booked project occupies three working days")
    func threeDayProject() throws {
        let dates = storedSchedule(duration: 3, start: "2026-08-31")
        #expect(dates == ["2026-08-31", "2026-09-01", "2026-09-02"])
    }

    @Test("5-day booked project occupies a full working week")
    func fiveDayProject() throws {
        let dates = storedSchedule(duration: 5, start: "2026-08-31")
        #expect(dates == ["2026-08-31", "2026-09-01", "2026-09-02", "2026-09-03", "2026-09-04"])
    }

    @Test("Weekend days never count toward a stored project's duration")
    func weekendCrossing() throws {
        let dates = storedSchedule(duration: 3, start: "2026-09-04")
        #expect(dates == ["2026-09-04", "2026-09-07", "2026-09-08"])
    }

    @Test("Marking a project completed keeps it in history")
    func markingCompleted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let project = Project(
            projectName: "Kitchen",
            customerName: "Nguyen",
            status: .booked,
            startDate: TestCalendar.date("2026-08-31"),
            durationInWorkingDays: 3
        )
        context.insert(project)
        try context.save()

        let completedAt = TestCalendar.date("2026-09-10")
        project.markCompleted(at: completedAt)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Project>()).first)
        #expect(fetched.status == .completed)
        #expect(fetched.completedDate == completedAt)
        #expect(fetched.projectName == "Kitchen")
    }

    @Test("Completed project no longer blocks future availability")
    func completedDoesNotBlock() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let project = Project(
            projectName: "Kitchen",
            customerName: "Nguyen",
            status: .booked,
            startDate: TestCalendar.date("2026-08-31"),
            durationInWorkingDays: 5
        )
        context.insert(project)
        try context.save()
        #expect(!engine.occupiedDates(from: [project.snapshot]).isEmpty)

        project.markCompleted(at: TestCalendar.date("2026-09-10"))
        try context.save()
        #expect(engine.occupiedDates(from: [project.snapshot]).isEmpty)
        #expect(engine.availability(on: TestCalendar.date("2026-08-31"), projects: [project.snapshot]) == .free)
    }

    @Test("Deleting a project removes it from the store")
    func deletingAProject() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let project = Project(
            projectName: "Remove me",
            customerName: "Lee",
            status: .quoted,
            durationInWorkingDays: 1
        )
        context.insert(project)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Project>()).count == 1)

        context.delete(project)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    private func storedSchedule(duration: Int, start: String) -> [String] {
        let project = Project(
            projectName: "Job",
            customerName: "Customer",
            status: .booked,
            startDate: TestCalendar.date(start),
            durationInWorkingDays: duration
        )
        return engine.workingDates(
            start: project.startDate ?? .now,
            duration: project.durationInWorkingDays
        ).map(TestCalendar.iso)
    }
}

import Foundation
@testable import FreeDay
import Testing

struct ProjectValidatorTests {
    private func validQuoted() -> ProjectDraft {
        ProjectDraft(
            projectName: "Interior painting",
            customerName: "Smith House",
            status: .quoted,
            startDate: nil,
            durationInWorkingDays: 3
        )
    }

    @Test("Quoted project without a start date is valid")
    func quotedWithoutStartDate() {
        let errors = ProjectValidator.errors(in: validQuoted())
        #expect(errors.isEmpty)
        #expect(!validQuoted().asSnapshot().blocksAvailability)
    }

    @Test("BOOKED project requires a start date")
    func bookedRequiresStartDate() {
        var draft = validQuoted()
        draft.status = .booked
        draft.startDate = nil
        #expect(ProjectValidator.errors(in: draft) == [.bookedMissingStartDate])
        #expect(ProjectValidator.firstMessage(in: draft) == "Choose a start date for a booked job.")
    }

    @Test("BOOKED project with a start date is valid")
    func bookedWithStartDate() {
        var draft = validQuoted()
        draft.status = .booked
        draft.startDate = TestCalendar.date("2026-08-31")
        #expect(ProjectValidator.errors(in: draft).isEmpty)
        #expect(draft.asSnapshot().blocksAvailability)
    }

    @Test("Missing project name")
    func missingProjectName() {
        var draft = validQuoted()
        draft.projectName = "   "
        #expect(ProjectValidator.errors(in: draft) == [.missingProjectName])
        #expect(ProjectValidator.firstMessage(in: draft) == "Enter a project name.")
    }

    @Test("Missing customer name")
    func missingCustomerName() {
        var draft = validQuoted()
        draft.customerName = ""
        #expect(ProjectValidator.errors(in: draft) == [.missingCustomerName])
        #expect(ProjectValidator.firstMessage(in: draft) == "Enter a customer name.")
    }

    @Test("Invalid duration")
    func invalidDuration() {
        var draft = validQuoted()
        draft.durationInWorkingDays = 0
        #expect(ProjectValidator.errors(in: draft) == [.invalidDuration])
        #expect(ProjectValidator.firstMessage(in: draft) == "Enter at least 1 working day.")
    }

    @Test("Invalid buffer")
    func invalidBuffer() {
        var draft = validQuoted()
        draft.bufferInWorkingDays = -1
        #expect(ProjectValidator.errors(in: draft) == [.invalidBuffer])
        draft.bufferInWorkingDays = 11
        #expect(ProjectValidator.errors(in: draft) == [.invalidBuffer])
        draft.bufferInWorkingDays = 0
        #expect(ProjectValidator.errors(in: draft).isEmpty)
    }
}

private extension ProjectDraft {
    func asSnapshot() -> ProjectSnapshot {
        let trimmed = trimmed()
        return ProjectSnapshot(
            id: UUID(),
            projectName: trimmed.projectName,
            customerName: trimmed.customerName,
            phoneNumber: trimmed.phoneNumber.isEmpty ? nil : trimmed.phoneNumber,
            address: trimmed.address.isEmpty ? nil : trimmed.address,
            notes: trimmed.notes.isEmpty ? nil : trimmed.notes,
            status: trimmed.status,
            startDate: trimmed.startDate,
            durationInWorkingDays: trimmed.durationInWorkingDays,
            bufferInWorkingDays: trimmed.bufferInWorkingDays,
            createdDate: TestCalendar.date("2026-08-01"),
            completedDate: nil
        )
    }
}

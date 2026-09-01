import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID
    /// Maps from the Step 1 stored name so existing local data keeps loading.
    @Attribute(originalName: "name")
    var projectName: String
    var customerName: String
    @Attribute(originalName: "phone")
    var phoneNumber: String?
    var address: String?
    var notes: String?
    /// Stored as a string so future statuses can be added without a schema break.
    var statusRaw: String
    var startDate: Date?
    @Attribute(originalName: "durationWorkingDays")
    var durationInWorkingDays: Int
    var bufferInWorkingDays: Int = 0
    @Attribute(originalName: "createdAt")
    var createdDate: Date
    @Attribute(originalName: "completedAt")
    var completedDate: Date?

    init(
        id: UUID = UUID(),
        projectName: String,
        customerName: String,
        phoneNumber: String? = nil,
        address: String? = nil,
        notes: String? = nil,
        status: ProjectStatus,
        startDate: Date? = nil,
        durationInWorkingDays: Int,
        bufferInWorkingDays: Int = 0,
        createdDate: Date = .now,
        completedDate: Date? = nil
    ) {
        self.id = id
        self.projectName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.customerName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.phoneNumber = Self.normalizedOptional(phoneNumber)
        self.address = Self.normalizedOptional(address)
        self.notes = Self.normalizedOptional(notes)
        self.statusRaw = status.rawValue
        self.startDate = startDate
        self.durationInWorkingDays = durationInWorkingDays
        self.bufferInWorkingDays = max(0, bufferInWorkingDays)
        self.createdDate = createdDate
        self.completedDate = completedDate
        if status == .completed, self.completedDate == nil {
            self.completedDate = createdDate
        }
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .quoted }
        set { statusRaw = newValue.rawValue }
    }

    var snapshot: ProjectSnapshot {
        ProjectSnapshot(
            id: id,
            projectName: projectName,
            customerName: customerName,
            phoneNumber: phoneNumber,
            address: address,
            notes: notes,
            status: status,
            startDate: startDate,
            durationInWorkingDays: durationInWorkingDays,
            bufferInWorkingDays: max(0, bufferInWorkingDays),
            createdDate: createdDate,
            completedDate: completedDate
        )
    }

    func apply(_ draft: ProjectDraft) {
        let trimmed = draft.trimmed()
        projectName = trimmed.projectName
        customerName = trimmed.customerName
        phoneNumber = trimmed.phoneNumber.isEmpty ? nil : trimmed.phoneNumber
        address = trimmed.address.isEmpty ? nil : trimmed.address
        notes = trimmed.notes.isEmpty ? nil : trimmed.notes
        startDate = trimmed.startDate
        durationInWorkingDays = trimmed.durationInWorkingDays
        bufferInWorkingDays = max(0, trimmed.bufferInWorkingDays)
        applyStatus(trimmed.status)
    }

    func applyStatus(_ newStatus: ProjectStatus, completedAt date: Date = .now) {
        status = newStatus
        if newStatus == .completed {
            if completedDate == nil {
                completedDate = date
            }
        } else {
            completedDate = nil
        }
    }

    func markCompleted(at date: Date = .now) {
        applyStatus(.completed, completedAt: date)
    }

    var draft: ProjectDraft {
        ProjectDraft(
            projectName: projectName,
            customerName: customerName,
            phoneNumber: phoneNumber ?? "",
            address: address ?? "",
            notes: notes ?? "",
            status: status,
            startDate: startDate,
            durationInWorkingDays: durationInWorkingDays,
            bufferInWorkingDays: bufferInWorkingDays
        )
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

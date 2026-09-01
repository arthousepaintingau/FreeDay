import Foundation

/// Editable project fields, independent of SwiftData so validation is testable.
struct ProjectDraft: Equatable, Sendable {
    var projectName: String = ""
    var customerName: String = ""
    var phoneNumber: String = ""
    var address: String = ""
    var notes: String = ""
    var status: ProjectStatus = .quoted
    var startDate: Date? = nil
    var durationInWorkingDays: Int = 1
    var bufferInWorkingDays: Int = 0

    func trimmed() -> ProjectDraft {
        var copy = self
        copy.projectName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.customerName = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }

    var optionalPhone: String? { trimmed().phoneNumber.isEmpty ? nil : trimmed().phoneNumber }
    var optionalAddress: String? { trimmed().address.isEmpty ? nil : trimmed().address }
    var optionalNotes: String? { trimmed().notes.isEmpty ? nil : trimmed().notes }
}

enum ProjectValidationError: Equatable, Sendable {
    case missingProjectName
    case missingCustomerName
    case invalidDuration
    case invalidBuffer
    case bookedMissingStartDate

    var message: String {
        switch self {
        case .missingProjectName:
            String(localized: "Enter a project name.", comment: "Validation")
        case .missingCustomerName:
            String(localized: "Enter a customer name.", comment: "Validation")
        case .invalidDuration:
            String(localized: "Enter at least 1 working day.", comment: "Validation")
        case .invalidBuffer:
            String(localized: "Buffer must be between 0 and 10 working days.", comment: "Validation")
        case .bookedMissingStartDate:
            String(localized: "Choose a start date for a booked job.", comment: "Validation")
        }
    }
}

enum ProjectValidator {
    static func errors(in draft: ProjectDraft) -> [ProjectValidationError] {
        let trimmed = draft.trimmed()
        var errors: [ProjectValidationError] = []
        if trimmed.projectName.isEmpty {
            errors.append(.missingProjectName)
        }
        if trimmed.customerName.isEmpty {
            errors.append(.missingCustomerName)
        }
        if trimmed.durationInWorkingDays < 1 {
            errors.append(.invalidDuration)
        }
        if trimmed.bufferInWorkingDays < 0 || trimmed.bufferInWorkingDays > 10 {
            errors.append(.invalidBuffer)
        }
        if trimmed.status == .booked && trimmed.startDate == nil {
            errors.append(.bookedMissingStartDate)
        }
        return errors
    }

    static func firstMessage(in draft: ProjectDraft) -> String? {
        errors(in: draft).first?.message
    }
}

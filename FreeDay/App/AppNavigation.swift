import SwiftUI

struct ProjectPrefill: Hashable {
    var projectName: String = ""
    var customerName: String = ""
    var startDate: Date?
    var durationInWorkingDays: Int = 1
    var status: ProjectStatus = .quoted
    var showFitMessage: Bool = false
}

enum AppTab: Hashable {
    case home
    case week
    case jobs
}

enum AppSheet: Identifiable {
    case findFreeDays
    case quickCheck
    case addProject(ProjectPrefill)
    case paywall

    var id: String {
        switch self {
        case .findFreeDays: "findFreeDays"
        case .quickCheck: "quickCheck"
        case .addProject: "addProject"
        case .paywall: "paywall"
        }
    }
}

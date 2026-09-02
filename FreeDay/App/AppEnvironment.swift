import SwiftUI

/// Shared runtime services. Keep this value-typed so views stay simple and tests can inject fakes.
struct AppEnvironment: Sendable {
    var workingCalendar: WorkingCalendar
    var scheduling: SchedulingEngine
    var availabilitySearch: AvailabilitySearch

    static let australiaDefault = make(settings: .australiaDefault)

    static func make(settings: WorkWeekSettings) -> AppEnvironment {
        make(workingCalendar: WorkingCalendar(settings: settings))
    }

    static func make(workingCalendar: WorkingCalendar) -> AppEnvironment {
        let engine = SchedulingEngine(workingCalendar: workingCalendar)
        return AppEnvironment(
            workingCalendar: workingCalendar,
            scheduling: engine,
            availabilitySearch: AvailabilitySearch(engine: engine)
        )
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.australiaDefault
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

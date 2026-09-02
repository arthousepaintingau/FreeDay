import Foundation
import Observation

/// App-level working-day preference. Single source of truth for Saturday/Sunday.
/// Monday–Friday stay on. Persists in UserDefaults so existing users keep Mon–Fri.
@MainActor
@Observable
final class WorkWeekStore {
    static let saturdayKey = "workWeek.worksSaturday"
    static let sundayKey = "workWeek.worksSunday"

    private let defaults: UserDefaults

    var worksSaturday: Bool {
        didSet { defaults.set(worksSaturday, forKey: Self.saturdayKey) }
    }

    var worksSunday: Bool {
        didSet { defaults.set(worksSunday, forKey: Self.sundayKey) }
    }

    var settings: WorkWeekSettings {
        .australia(worksSaturday: worksSaturday, worksSunday: worksSunday)
    }

    var appEnvironment: AppEnvironment {
        .make(settings: settings)
    }

    init(defaults: UserDefaults? = nil) {
        let resolved = defaults ?? Self.defaultsForCurrentProcess()
        self.defaults = resolved
        self.worksSaturday = resolved.object(forKey: Self.saturdayKey) as? Bool ?? false
        self.worksSunday = resolved.object(forKey: Self.sundayKey) as? Bool ?? false
    }

    private static func defaultsForCurrentProcess() -> UserDefaults {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            let name = "au.freeday.ui-testing.workweek"
            let suite = UserDefaults(suiteName: name) ?? .standard
            suite.removePersistentDomain(forName: name)
            return suite
        }
        return .standard
    }
}

import Foundation

/// Isolated 30-day free-access clock.
///
/// Records a write-once trial start date in UserDefaults on first launch.
/// Does not talk to StoreKit or present UI. Access is `trialActive || isSubscribed`.
final class ProAccessStore {
    static let trialStartDateKey = "proAccess.trialStartDate"
    static let trialDurationDays = 30

    private static let secondsPerDay: TimeInterval = 86_400

    private let now: () -> Date
    private let calendar: Calendar

    /// First-launch moment. Never overwritten on later launches.
    let trialStartDate: Date

    init(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.now = now
        self.calendar = calendar
        if let stored = defaults.object(forKey: Self.trialStartDateKey) as? Date {
            self.trialStartDate = stored
        } else {
            let start = now()
            defaults.set(start, forKey: Self.trialStartDateKey)
            self.trialStartDate = start
        }
    }

    /// App launch hook so the start date is stored without touching UI.
    static func recordFirstLaunchIfNeeded(
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        _ = ProAccessStore(defaults: defaults, now: now)
    }

    var expiryDate: Date {
        calendar.date(byAdding: .day, value: Self.trialDurationDays, to: trialStartDate)
            ?? trialStartDate.addingTimeInterval(Self.secondsPerDay * TimeInterval(Self.trialDurationDays))
    }

    var trialExpired: Bool {
        now() >= expiryDate
    }

    var trialActive: Bool {
        !trialExpired
    }

    var daysRemaining: Int {
        let remaining = expiryDate.timeIntervalSince(now())
        guard remaining > 0 else { return 0 }
        return Int(ceil(remaining / Self.secondsPerDay))
    }

    /// Full app access while the 30-day trial is active, or while a verified subscription is active.
    func hasFullAccess(isSubscribed: Bool) -> Bool {
        trialActive || isSubscribed
    }

    /// Trial-only convenience. Prefer `hasFullAccess(isSubscribed:)`.
    var hasFullAccess: Bool {
        hasFullAccess(isSubscribed: false)
    }
}

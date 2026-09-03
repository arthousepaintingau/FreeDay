import Foundation
@testable import FreeDay
import Testing

struct ProAccessTests {
    private let start = Date(timeIntervalSince1970: 1_788_336_000) // 2026-09-02 00:00 GMT

    private var gmt: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "au.freeday.tests.proaccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func store(
        defaults: UserDefaults,
        now: Date,
        simulateExpiredTrial: Bool = false
    ) -> ProAccessStore {
        ProAccessStore(
            defaults: defaults,
            now: { now },
            calendar: gmt,
            simulateExpiredTrial: simulateExpiredTrial
        )
    }

    @Test("First launch creates the trial start date")
    func firstLaunchCreatesStartDate() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let access = store(defaults: defaults, now: start)

        let stored = defaults.object(forKey: ProAccessStore.trialStartDateKey) as? Date
        #expect(stored == start)
        #expect(access.trialStartDate == start)
    }

    @Test("Subsequent launches preserve the same start date")
    func subsequentLaunchesPreserveStartDate() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = store(defaults: defaults, now: start)
        let later = start.addingTimeInterval(86_400 * 5)
        let second = store(defaults: defaults, now: later)

        #expect(second.trialStartDate == first.trialStartDate)
        #expect(second.trialStartDate == start)
        #expect(defaults.object(forKey: ProAccessStore.trialStartDateKey) as? Date == start)
    }

    @Test("Access is active before 30 days")
    func accessActiveBeforeThirtyDays() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start)
        let day29 = gmt.date(byAdding: .day, value: 29, to: start)!
        let access = store(defaults: defaults, now: day29)

        #expect(access.trialActive)
        #expect(!access.trialExpired)
        #expect(access.daysRemaining == 1)
        #expect(access.hasFullAccess)
    }

    @Test("Access is expired after 30 days")
    func accessExpiredAfterThirtyDays() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start)
        let after = gmt.date(byAdding: .day, value: 30, to: start)!.addingTimeInterval(1)
        let access = store(defaults: defaults, now: after)

        #expect(!access.trialActive)
        #expect(access.trialExpired)
        #expect(access.daysRemaining == 0)
        #expect(!access.hasFullAccess)
    }

    @Test("Exactly 30 days is the expiry instant")
    func exactlyThirtyDaysIsExpired() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let first = store(defaults: defaults, now: start)
        #expect(first.trialActive)
        #expect(first.daysRemaining == 30)

        let expiry = gmt.date(byAdding: .day, value: 30, to: start)!
        let atExpiry = store(defaults: defaults, now: expiry)
        #expect(!atExpiry.trialActive)
        #expect(atExpiry.trialExpired)
        #expect(atExpiry.daysRemaining == 0)

        let lastSecond = store(defaults: defaults, now: expiry.addingTimeInterval(-1))
        #expect(lastSecond.trialActive)
        #expect(!lastSecond.trialExpired)
        #expect(lastSecond.daysRemaining == 1)
    }

    @Test("Trial active with no subscription is unlocked")
    func trialActiveWithoutSubscriptionIsUnlocked() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let access = store(defaults: defaults, now: start)

        #expect(access.trialActive)
        #expect(access.hasFullAccess(isSubscribed: false))
    }

    @Test("Expired trial with an active subscription is unlocked")
    func expiredTrialWithActiveSubscriptionIsUnlocked() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start)
        let after = gmt.date(byAdding: .day, value: 30, to: start)!.addingTimeInterval(1)
        let access = store(defaults: defaults, now: after)

        #expect(access.trialExpired)
        #expect(access.hasFullAccess(isSubscribed: true))
    }

    @Test("Expired trial with no subscription is locked")
    func expiredTrialWithoutSubscriptionIsLocked() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start)
        let after = gmt.date(byAdding: .day, value: 30, to: start)!.addingTimeInterval(1)
        let access = store(defaults: defaults, now: after)

        #expect(access.trialExpired)
        #expect(!access.hasFullAccess(isSubscribed: false))
    }

    @Test("Production access logic is unchanged when the DEBUG expiry hook is off")
    func productionAccessLogicUnchangedWhenHookIsOff() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start, simulateExpiredTrial: false)

        let day29 = gmt.date(byAdding: .day, value: 29, to: start)!
        let active = store(defaults: defaults, now: day29, simulateExpiredTrial: false)
        #expect(active.trialActive)
        #expect(!active.trialExpired)
        #expect(active.daysRemaining == 1)
        #expect(active.hasFullAccess(isSubscribed: false))
        #expect(active.hasFullAccess(isSubscribed: true))

        let after = gmt.date(byAdding: .day, value: 30, to: start)!.addingTimeInterval(1)
        let expired = store(defaults: defaults, now: after, simulateExpiredTrial: false)
        #expect(expired.trialExpired)
        #expect(!expired.trialActive)
        #expect(expired.daysRemaining == 0)
        #expect(!expired.hasFullAccess(isSubscribed: false))
        #expect(expired.hasFullAccess(isSubscribed: true))
        #expect(expired.trialStartDate == start)
        #expect(expired.expiryDate == gmt.date(byAdding: .day, value: 30, to: start))
    }

    #if DEBUG
    @Test("DEBUG expiry hook forces lock without changing the stored trial start date")
    func debugExpiryHookForcesLockWithoutChangingStartDate() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        _ = store(defaults: defaults, now: start, simulateExpiredTrial: false)
        let forced = store(defaults: defaults, now: start, simulateExpiredTrial: true)

        #expect(forced.trialStartDate == start)
        #expect(defaults.object(forKey: ProAccessStore.trialStartDateKey) as? Date == start)
        #expect(forced.expiryDate == gmt.date(byAdding: .day, value: 30, to: start))
        #expect(forced.trialExpired)
        #expect(!forced.trialActive)
        #expect(!forced.hasFullAccess(isSubscribed: false))
        #expect(forced.hasFullAccess(isSubscribed: true))
    }
    #endif
}

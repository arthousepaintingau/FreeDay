import Foundation
import Observation
@testable import FreeDay
import Testing

private let frozenNow = Date(timeIntervalSince1970: 1_788_336_000)
private let monthlyExpiry = frozenNow.addingTimeInterval(86_400 * 30)
private let yearlyExpiry = frozenNow.addingTimeInterval(86_400 * 365)

@MainActor
struct SubscriptionStoreTests {
    private func monthly(
        expires: Date? = monthlyExpiry,
        revoked: Date? = nil
    ) -> SubscriptionEntitlement {
        SubscriptionEntitlement(productID: .monthly, expirationDate: expires, revocationDate: revoked)
    }

    private func yearly(
        expires: Date? = yearlyExpiry
    ) -> SubscriptionEntitlement {
        SubscriptionEntitlement(productID: .yearly, expirationDate: expires, revocationDate: nil)
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "au.freeday.tests.subscription.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeStore(
        _ commerce: FakeSubscriptionCommerce,
        defaults: UserDefaults? = nil
    ) -> SubscriptionStore {
        SubscriptionStore(commerce: commerce, now: { frozenNow }, defaults: defaults ?? isolatedDefaults())
    }

    private func writePersisted(
        _ record: VerifiedSubscriptionPersistence.Record,
        to defaults: UserDefaults
    ) {
        defaults.set(try? JSONEncoder().encode(record), forKey: VerifiedSubscriptionPersistence.key)
    }

    @Test("Product IDs match App Store Connect")
    func productIDsMatchAppStoreConnect() {
        #expect(SubscriptionProductID.monthly.rawValue == "app.freeday.FreeDay.monthly")
        #expect(SubscriptionProductID.yearly.rawValue == "app.freeday.FreeDay.yearly")
        #expect(Set(SubscriptionProductID.allIDs) == [
            "app.freeday.FreeDay.monthly",
            "app.freeday.FreeDay.yearly",
        ])
    }

    @Test("No entitlements means not subscribed")
    func noEntitlementsMeansNotSubscribed() async {
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
    }

    @Test("Active monthly entitlement is subscribed")
    func activeMonthlyEntitlement() async {
        let commerce = FakeSubscriptionCommerce()
        let entitlement = monthly()
        commerce.entitlements = [entitlement]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: entitlement.expirationDate))
    }

    @Test("Active yearly entitlement is subscribed")
    func activeYearlyEntitlement() async {
        let commerce = FakeSubscriptionCommerce()
        let entitlement = yearly()
        commerce.entitlements = [entitlement]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: entitlement.expirationDate))
    }

    @Test("Revoked entitlement does not grant access")
    func revokedEntitlementDoesNotGrantAccess() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlements = [monthly(revoked: frozenNow)]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
    }

    @Test("Expired entitlement does not grant access")
    func expiredEntitlementDoesNotGrantAccess() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlements = [monthly(expires: frozenNow)]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
    }

    @Test("Revoked or expired entitlements are inactive")
    func revokedOrExpiredEntitlementsAreInactive() {
        #expect(monthly().isActive(at: frozenNow))
        #expect(!monthly(revoked: frozenNow).isActive(at: frozenNow))
        #expect(!monthly(expires: frozenNow).isActive(at: frozenNow))
        #expect(monthly(expires: frozenNow.addingTimeInterval(1)).isActive(at: frozenNow))
    }

    @Test("Purchase monthly uses the monthly product ID")
    func purchaseMonthlyUsesMonthlyID() async throws {
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce)
        let outcome = try await store.purchaseMonthly()
        #expect(outcome == .success)
        #expect(commerce.purchased == [.monthly])
    }

    @Test("Purchase yearly uses the yearly product ID")
    func purchaseYearlyUsesYearlyID() async throws {
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce)
        let outcome = try await store.purchaseYearly()
        #expect(outcome == .success)
        #expect(commerce.purchased == [.yearly])
    }

    @Test("Successful purchase refreshes entitlements")
    func successfulPurchaseRefreshesEntitlements() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterPurchase = [monthly()]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        let ledgerCallsBeforePurchase = commerce.currentEntitlementsCallCount
        _ = try await store.purchaseMonthly()
        #expect(store.isSubscribed)
        #expect(commerce.currentEntitlementsCallCount == ledgerCallsBeforePurchase + 1)
    }

    @Test("Verified purchase activates immediately when current entitlements are still empty")
    func verifiedPurchaseActivatesImmediatelyWhenLedgerIsEmpty() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        #expect(!store.isSubscribed)
        #expect(commerce.entitlements.isEmpty)

        let outcome = try await store.purchaseMonthly()

        #expect(outcome == .success)
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))
        #expect(commerce.entitlements.isEmpty)
        #expect(commerce.currentEntitlementsCallCount == 1)
    }

    @Test("Empty currentEntitlements refresh does not erase a verified purchase")
    func emptyLedgerRefreshDoesNotEraseVerifiedPurchase() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        _ = try await store.purchaseMonthly()
        #expect(store.isSubscribed)
        #expect(commerce.entitlements.isEmpty)

        await store.startAndRefresh()

        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))
        #expect(commerce.entitlements.isEmpty)
    }

    @Test("Transaction updates with an empty ledger do not erase a verified purchase")
    func transactionUpdatesWithEmptyLedgerDoNotEraseVerifiedPurchase() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        await store.startAndRefresh()
        _ = try await store.purchaseMonthly()
        #expect(store.isSubscribed)

        commerce.emitUpdate()

        var stillSubscribed = true
        for _ in 0..<20 {
            if !store.isSubscribed {
                stillSubscribed = false
                break
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(stillSubscribed)
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))
    }

    @Test("Active ledger entitlements still reconcile after a verified purchase")
    func activeLedgerStillReconcilesAfterVerifiedPurchase() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        _ = try await store.purchaseMonthly()
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))

        commerce.entitlements = [yearly()]
        await store.startAndRefresh()

        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: yearlyExpiry))
    }

    @Test("Settings subscribed copy follows a verified purchase that the ledger has not caught up to")
    func settingsSubscribedCopyFollowsVerifiedPurchaseWhenLedgerIsEmpty() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        _ = try await store.purchaseMonthly()
        await store.startAndRefresh()

        #expect(store.isSubscribed)
        #expect(settingsProRowTitle(isSubscribed: store.isSubscribed) == "View FreeWorkDates Pro")
        #expect(
            settingsProCaption(isSubscribed: store.isSubscribed)
                == "View your FreeWorkDates Pro plans. Restore Purchases is available on the next screen."
        )
    }

    @Test("Unverified purchase does not activate Pro")
    func unverifiedPurchaseDoesNotActivatePro() async {
        let defaults = isolatedDefaults()
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseError = .unverified
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce, defaults: defaults)

        do {
            _ = try await store.purchaseMonthly()
            Issue.record("Expected unverified purchase to throw")
        } catch {
            #expect(error as? SubscriptionError == .unverified)
        }
        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
        #expect(commerce.currentEntitlementsCallCount == 0)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)
        #expect(VerifiedSubscriptionPersistence.loadActive(from: defaults, now: frozenNow) == nil)
    }

    @Test("Cancelled purchase does not activate Pro")
    func cancelledPurchaseDoesNotActivatePro() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseOutcome = .userCancelled
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)

        let outcome = try await store.purchaseMonthly()

        #expect(outcome == .userCancelled)
        #expect(!store.isSubscribed)
        #expect(commerce.currentEntitlementsCallCount == 0)
    }

    @Test("Pending purchase does not activate Pro")
    func pendingPurchaseDoesNotActivatePro() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseOutcome = .pending
        commerce.purchasedEntitlement = yearly()
        let store = makeStore(commerce)

        let outcome = try await store.purchaseYearly()

        #expect(outcome == .pending)
        #expect(!store.isSubscribed)
        #expect(commerce.currentEntitlementsCallCount == 0)
    }

    @Test("Purchase does not change expired-trial access rules")
    func purchaseDoesNotChangeExpiredTrialAccessRules() async throws {
        let suiteName = "au.freeday.tests.purchase.trial.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = TimeZone(secondsFromGMT: 0)!
        let trialStart = frozenNow
        _ = ProAccessStore(defaults: defaults, now: { trialStart }, calendar: gmt)

        let afterTrial = gmt.date(byAdding: .day, value: 30, to: trialStart)!.addingTimeInterval(1)
        let access = ProAccessStore(defaults: defaults, now: { afterTrial }, calendar: gmt)
        #expect(access.trialExpired)
        #expect(!access.hasFullAccess(isSubscribed: false))

        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce)
        _ = try await store.purchaseMonthly()

        #expect(store.isSubscribed)
        #expect(access.trialExpired)
        #expect(access.trialStartDate == trialStart)
        #expect(access.hasFullAccess(isSubscribed: false) == false)
        #expect(access.hasFullAccess(isSubscribed: store.isSubscribed))
    }

    @Test("Revoked or expired purchase entitlement does not activate Pro")
    func revokedOrExpiredPurchaseEntitlementDoesNotActivatePro() async throws {
        let revoked = FakeSubscriptionCommerce()
        revoked.purchasedEntitlement = monthly(revoked: frozenNow)
        let revokedStore = makeStore(revoked)
        _ = try await revokedStore.purchaseMonthly()
        #expect(!revokedStore.isSubscribed)

        let expired = FakeSubscriptionCommerce()
        expired.purchasedEntitlement = monthly(expires: frozenNow)
        let expiredStore = makeStore(expired)
        _ = try await expiredStore.purchaseMonthly()
        #expect(!expiredStore.isSubscribed)
    }

    @Test("Purchase publishes an observable subscription change")
    func purchasePublishesObservableSubscriptionChange() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterPurchase = [monthly()]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)

        let didChange = ObservationChangeFlag()
        withObservationTracking {
            _ = store.isSubscribed
        } onChange: {
            didChange.value = true
        }

        _ = try await store.purchaseMonthly()
        #expect(store.isSubscribed)
        #expect(didChange.value)
    }

    @Test("Restore publishes an observable subscription change")
    func restorePublishesObservableSubscriptionChange() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterRestore = [yearly()]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)

        let didChange = ObservationChangeFlag()
        withObservationTracking {
            _ = store.isSubscribed
        } onChange: {
            didChange.value = true
        }

        try await store.restorePurchases()
        #expect(store.isSubscribed)
        #expect(didChange.value)
    }

    @Test("Restore purchases syncs then refreshes entitlements")
    func restorePurchasesSyncsThenRefreshes() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterRestore = [yearly()]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        try await store.restorePurchases()
        #expect(commerce.restoreCount == 1)
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: yearlyExpiry))
    }

    @Test("Transaction updates refresh entitlements")
    func transactionUpdatesRefreshEntitlements() async {
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(!store.isSubscribed)

        commerce.entitlements = [monthly()]
        commerce.emitUpdate()

        var subscribed = false
        for _ in 0..<50 {
            if store.isSubscribed {
                subscribed = true
                break
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(subscribed)
    }

    @Test("Start finishes unfinished verified transactions")
    func startFinishesUnfinishedVerifiedTransactions() async {
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(commerce.finishUnfinishedCount == 1)
    }

    @Test("Loaded products come from commerce, empty is allowed")
    func loadedProductsComeFromCommerce() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.products = [
            LoadedSubscriptionProduct(id: .monthly, displayName: "Monthly", displayPrice: "$4.99"),
            LoadedSubscriptionProduct(id: .yearly, displayName: "Yearly", displayPrice: "$39.99"),
        ]
        let store = makeStore(commerce)
        await store.startAndRefresh()
        #expect(store.monthlyProduct?.id == .monthly)
        #expect(store.yearlyProduct?.id == .yearly)
    }

    @Test("Verified active purchase is persisted")
    func verifiedActivePurchaseIsPersisted() async throws {
        let defaults = isolatedDefaults()
        let commerce = FakeSubscriptionCommerce()
        commerce.purchasedEntitlement = monthly()
        let store = makeStore(commerce, defaults: defaults)

        _ = try await store.purchaseMonthly()

        #expect(store.isSubscribed)
        #expect(VerifiedSubscriptionPersistence.loadActive(from: defaults, now: frozenNow) == monthly())
    }

    @Test("Persisted verified entitlement survives a new store with an empty ledger")
    func persistedEntitlementSurvivesProcessRestartWithEmptyLedger() async throws {
        let defaults = isolatedDefaults()
        let purchaseCommerce = FakeSubscriptionCommerce()
        purchaseCommerce.purchasedEntitlement = monthly()
        let original = makeStore(purchaseCommerce, defaults: defaults)
        _ = try await original.purchaseMonthly()
        #expect(original.isSubscribed)

        let relaunchCommerce = FakeSubscriptionCommerce()
        #expect(relaunchCommerce.entitlements.isEmpty)
        let relaunched = makeStore(relaunchCommerce, defaults: defaults)

        #expect(relaunched.isSubscribed)
        #expect(relaunched.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))
    }

    @Test("Empty launch refresh does not wipe a valid persisted entitlement")
    func emptyLaunchRefreshDoesNotWipePersistedEntitlement() async throws {
        let defaults = isolatedDefaults()
        let purchaseCommerce = FakeSubscriptionCommerce()
        purchaseCommerce.purchasedEntitlement = monthly()
        let original = makeStore(purchaseCommerce, defaults: defaults)
        _ = try await original.purchaseMonthly()

        let relaunchCommerce = FakeSubscriptionCommerce()
        let relaunched = makeStore(relaunchCommerce, defaults: defaults)
        await relaunched.startAndRefresh()

        #expect(relaunched.isSubscribed)
        #expect(relaunched.status == .subscribed(productID: .monthly, expirationDate: monthlyExpiry))
        #expect(VerifiedSubscriptionPersistence.loadActive(from: defaults, now: frozenNow) == monthly())
        #expect(relaunchCommerce.entitlements.isEmpty)
    }

    @Test("Active StoreKit ledger takes precedence over persisted fallback")
    func activeLedgerTakesPrecedenceOverPersistedFallback() async {
        let defaults = isolatedDefaults()
        VerifiedSubscriptionPersistence.save(monthly(), to: defaults, now: frozenNow)

        let commerce = FakeSubscriptionCommerce()
        commerce.entitlements = [yearly()]
        let store = makeStore(commerce, defaults: defaults)
        await store.startAndRefresh()

        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: yearlyExpiry))
        #expect(VerifiedSubscriptionPersistence.loadActive(from: defaults, now: frozenNow) == yearly())
    }

    @Test("Expired persisted entitlement does not unlock Pro and is removed")
    func expiredPersistedEntitlementDoesNotUnlockPro() {
        let defaults = isolatedDefaults()
        writePersisted(
            VerifiedSubscriptionPersistence.Record(
                productID: SubscriptionProductID.monthly.rawValue,
                expirationDate: frozenNow,
                revocationDate: nil
            ),
            to: defaults
        )

        let store = makeStore(FakeSubscriptionCommerce(), defaults: defaults)

        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)
    }

    @Test("Revoked persisted entitlement does not unlock Pro")
    func revokedPersistedEntitlementDoesNotUnlockPro() async {
        let defaults = isolatedDefaults()
        writePersisted(
            VerifiedSubscriptionPersistence.Record(
                productID: SubscriptionProductID.monthly.rawValue,
                expirationDate: monthlyExpiry,
                revocationDate: frozenNow
            ),
            to: defaults
        )

        let store = makeStore(FakeSubscriptionCommerce(), defaults: defaults)
        #expect(!store.isSubscribed)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)

        VerifiedSubscriptionPersistence.save(monthly(), to: defaults, now: frozenNow)
        let revokedLedger = FakeSubscriptionCommerce()
        revokedLedger.entitlements = [monthly(revoked: frozenNow)]
        let contradicted = makeStore(revokedLedger, defaults: defaults)
        await contradicted.startAndRefresh()

        #expect(!contradicted.isSubscribed)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)
    }

    @Test("Invalid persisted entitlement data does not unlock Pro")
    func invalidPersistedEntitlementDoesNotUnlockPro() {
        let defaults = isolatedDefaults()
        defaults.set(Data("not-json".utf8), forKey: VerifiedSubscriptionPersistence.key)

        let store = makeStore(FakeSubscriptionCommerce(), defaults: defaults)

        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)
    }

    @Test("Unknown persisted product ID never unlocks Pro")
    func unknownPersistedProductIDNeverUnlocksPro() {
        let defaults = isolatedDefaults()
        writePersisted(
            VerifiedSubscriptionPersistence.Record(
                productID: "com.other.app.monthly",
                expirationDate: monthlyExpiry,
                revocationDate: nil
            ),
            to: defaults
        )

        let store = makeStore(FakeSubscriptionCommerce(), defaults: defaults)

        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
        #expect(defaults.data(forKey: VerifiedSubscriptionPersistence.key) == nil)
    }

    @Test("Persisted fallback is not treated as a new purchase")
    func persistedFallbackIsNotANewPurchase() {
        let defaults = isolatedDefaults()
        VerifiedSubscriptionPersistence.save(monthly(), to: defaults, now: frozenNow)
        let commerce = FakeSubscriptionCommerce()
        let store = makeStore(commerce, defaults: defaults)

        #expect(store.isSubscribed)
        #expect(commerce.purchased.isEmpty)
        #expect(commerce.currentEntitlementsCallCount == 0)
    }

    @Test("Trial access remains trialActive or isSubscribed after persistence")
    func trialAccessRemainsTrialOrSubscribedAfterPersistence() async throws {
        let suiteName = "au.freeday.tests.persist.trial.\(UUID().uuidString)"
        let trialDefaults = UserDefaults(suiteName: suiteName)!
        trialDefaults.removePersistentDomain(forName: suiteName)
        defer { trialDefaults.removePersistentDomain(forName: suiteName) }

        var gmt = Calendar(identifier: .gregorian)
        gmt.timeZone = TimeZone(secondsFromGMT: 0)!
        let trialStart = frozenNow
        _ = ProAccessStore(defaults: trialDefaults, now: { trialStart }, calendar: gmt)

        let afterTrial = gmt.date(byAdding: .day, value: 30, to: trialStart)!.addingTimeInterval(1)
        let access = ProAccessStore(defaults: trialDefaults, now: { afterTrial }, calendar: gmt)
        #expect(access.trialExpired)
        #expect(!access.hasFullAccess(isSubscribed: false))

        let subscriptionDefaults = isolatedDefaults()
        VerifiedSubscriptionPersistence.save(monthly(), to: subscriptionDefaults, now: frozenNow)
        let store = makeStore(FakeSubscriptionCommerce(), defaults: subscriptionDefaults)

        #expect(store.isSubscribed)
        #expect(access.hasFullAccess(isSubscribed: store.isSubscribed))
        #expect(access.hasFullAccess(isSubscribed: false) == false)
    }
}

private func settingsProRowTitle(isSubscribed: Bool) -> String {
    isSubscribed ? "View FreeWorkDates Pro" : "Upgrade to FreeWorkDates Pro"
}

private func settingsProCaption(isSubscribed: Bool) -> String {
    if isSubscribed {
        return "View your FreeWorkDates Pro plans. Restore Purchases is available on the next screen."
    }
    return "Optional during your 30-day access period. View plans whenever you like. Restore Purchases is available on the next screen."
}

private final class ObservationChangeFlag: @unchecked Sendable {
    var value = false
}

final class FakeSubscriptionCommerce: SubscriptionCommerce, @unchecked Sendable {
    var products: [LoadedSubscriptionProduct] = []
    var entitlements: [SubscriptionEntitlement] = []
    var entitlementsAfterPurchase: [SubscriptionEntitlement]?
    var entitlementsAfterRestore: [SubscriptionEntitlement]?
    var purchasedEntitlement: SubscriptionEntitlement?
    var purchased: [SubscriptionProductID] = []
    var restoreCount = 0
    var finishUnfinishedCount = 0
    var currentEntitlementsCallCount = 0
    var purchaseOutcome: PurchaseOutcome = .success
    var purchaseError: SubscriptionError?
    var restoreError: SubscriptionError?

    private let continuation: AsyncStream<Void>.Continuation
    private let stream: AsyncStream<Void>

    init() {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.stream = stream
        self.continuation = continuation
    }

    func loadProducts() async throws -> [LoadedSubscriptionProduct] {
        products
    }

    func purchase(_ id: SubscriptionProductID) async throws -> (PurchaseOutcome, SubscriptionEntitlement?) {
        purchased.append(id)
        if let purchaseError {
            throw purchaseError
        }
        if purchaseOutcome != .success {
            return (purchaseOutcome, nil)
        }
        if let entitlementsAfterPurchase {
            entitlements = entitlementsAfterPurchase
        }
        let entitlement = purchasedEntitlement ?? entitlementsAfterPurchase?.first
        return (.success, entitlement)
    }

    func currentEntitlements() async -> [SubscriptionEntitlement] {
        currentEntitlementsCallCount += 1
        return entitlements
    }

    func transactionUpdates() -> AsyncStream<Void> {
        stream
    }

    func restore() async throws {
        restoreCount += 1
        if let restoreError {
            throw restoreError
        }
        if let entitlementsAfterRestore {
            entitlements = entitlementsAfterRestore
        }
    }

    func finishUnfinishedVerifiedTransactions() async {
        finishUnfinishedCount += 1
    }

    func emitUpdate() {
        continuation.yield()
    }
}

import Foundation
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
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
    }

    @Test("Active monthly entitlement is subscribed")
    func activeMonthlyEntitlement() async {
        let commerce = FakeSubscriptionCommerce()
        let entitlement = monthly()
        commerce.entitlements = [entitlement]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .monthly, expirationDate: entitlement.expirationDate))
    }

    @Test("Active yearly entitlement is subscribed")
    func activeYearlyEntitlement() async {
        let commerce = FakeSubscriptionCommerce()
        let entitlement = yearly()
        commerce.entitlements = [entitlement]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: entitlement.expirationDate))
    }

    @Test("Revoked entitlement does not grant access")
    func revokedEntitlementDoesNotGrantAccess() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlements = [monthly(revoked: frozenNow)]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        #expect(store.status == .notSubscribed)
    }

    @Test("Expired entitlement does not grant access")
    func expiredEntitlementDoesNotGrantAccess() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlements = [monthly(expires: frozenNow)]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
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
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        let outcome = try await store.purchaseMonthly()
        #expect(outcome == .success)
        #expect(commerce.purchased == [.monthly])
    }

    @Test("Purchase yearly uses the yearly product ID")
    func purchaseYearlyUsesYearlyID() async throws {
        let commerce = FakeSubscriptionCommerce()
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        let outcome = try await store.purchaseYearly()
        #expect(outcome == .success)
        #expect(commerce.purchased == [.yearly])
    }

    @Test("Successful purchase refreshes entitlements")
    func successfulPurchaseRefreshesEntitlements() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterPurchase = [monthly()]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(!store.isSubscribed)
        _ = try await store.purchaseMonthly()
        #expect(store.isSubscribed)
    }

    @Test("Restore purchases syncs then refreshes entitlements")
    func restorePurchasesSyncsThenRefreshes() async throws {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterRestore = [yearly()]
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        try await store.restorePurchases()
        #expect(commerce.restoreCount == 1)
        #expect(store.isSubscribed)
        #expect(store.status == .subscribed(productID: .yearly, expirationDate: yearlyExpiry))
    }

    @Test("Transaction updates refresh entitlements")
    func transactionUpdatesRefreshEntitlements() async {
        let commerce = FakeSubscriptionCommerce()
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
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
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
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
        let store = SubscriptionStore(commerce: commerce, now: { frozenNow })
        await store.startAndRefresh()
        #expect(store.monthlyProduct?.id == .monthly)
        #expect(store.yearlyProduct?.id == .yearly)
    }
}

final class FakeSubscriptionCommerce: SubscriptionCommerce, @unchecked Sendable {
    var products: [LoadedSubscriptionProduct] = []
    var entitlements: [SubscriptionEntitlement] = []
    var entitlementsAfterPurchase: [SubscriptionEntitlement]?
    var entitlementsAfterRestore: [SubscriptionEntitlement]?
    var purchased: [SubscriptionProductID] = []
    var restoreCount = 0
    var finishUnfinishedCount = 0
    var purchaseOutcome: PurchaseOutcome = .success

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

    func purchase(_ id: SubscriptionProductID) async throws -> PurchaseOutcome {
        purchased.append(id)
        if let entitlementsAfterPurchase {
            entitlements = entitlementsAfterPurchase
        }
        return purchaseOutcome
    }

    func currentEntitlements() async -> [SubscriptionEntitlement] {
        entitlements
    }

    func transactionUpdates() -> AsyncStream<Void> {
        stream
    }

    func restore() async throws {
        restoreCount += 1
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

import Foundation
@testable import FreeDay
import Testing

private let frozenNow = Date(timeIntervalSince1970: 1_788_336_000)

@MainActor
struct PaywallModelTests {
    private func monthlyProduct(price: String = "A$4.99") -> LoadedSubscriptionProduct {
        LoadedSubscriptionProduct(id: .monthly, displayName: "FreeDay Pro Monthly", displayPrice: price)
    }

    private func yearlyProduct(price: String = "A$49.99") -> LoadedSubscriptionProduct {
        LoadedSubscriptionProduct(id: .yearly, displayName: "FreeDay Pro Yearly", displayPrice: price)
    }

    private func makeStore(_ commerce: FakeSubscriptionCommerce) -> SubscriptionStore {
        SubscriptionStore(commerce: commerce, now: { frozenNow })
    }

    @Test("Headline and explanation match the ended-trial copy")
    func headlineAndExplanation() {
        #expect(PaywallCopy.headline == "Your 30-day free access has ended")
        #expect(PaywallCopy.explanation == "A Pro subscription is required to continue using FreeWorkDates.")
        #expect(PaywallCopy.headline(for: .expiredTrial, isSubscribed: false) == PaywallCopy.headline)
        #expect(PaywallCopy.explanation(for: .expiredTrial, isSubscribed: false) == PaywallCopy.explanation)
    }

    @Test("Voluntary trial copy does not claim the trial has ended")
    func voluntaryTrialCopy() {
        #expect(PaywallCopy.headline(for: .voluntary, isSubscribed: false) == "Upgrade to FreeWorkDates Pro")
        #expect(
            PaywallCopy.explanation(for: .voluntary, isSubscribed: false)
                == "Subscribe now for uninterrupted full access after your 30-day initial access period."
        )
        #expect(PaywallCopy.headline(for: .voluntary, isSubscribed: false) != PaywallCopy.headline)
    }

    @Test("Subscribed copy does not ask the user to buy again")
    func subscribedCopy() {
        #expect(PaywallCopy.headline(for: .voluntary, isSubscribed: true) == "You're subscribed to FreeWorkDates Pro.")
        #expect(PaywallCopy.headline(for: .expiredTrial, isSubscribed: true) == "You're subscribed to FreeWorkDates Pro.")
        #expect(
            PaywallCopy.explanation(for: .voluntary, isSubscribed: true)
                == "Your subscription is active. Restore Purchases can confirm it on this Apple Account."
        )
    }

    @Test("Subscribed product ID is read from existing store status")
    func subscribedProductIDFromStoreStatus() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterRestore = [
            SubscriptionEntitlement(productID: .yearly, expirationDate: frozenNow.addingTimeInterval(86_400), revocationDate: nil)
        ]
        let model = PaywallModel(store: makeStore(commerce))
        await model.restorePurchases()
        #expect(model.subscribedProductID == .yearly)
        #expect(model.isSubscribed)
    }

    @Test("Price text uses StoreKit displayPrice only")
    func priceTextUsesDisplayPrice() {
        #expect(PaywallCopy.priceText(for: monthlyProduct(price: "A$4.99")) == "A$4.99")
        #expect(PaywallCopy.priceText(for: monthlyProduct(price: "  ")) == nil)
        #expect(PaywallCopy.priceText(for: nil) == nil)
    }

    @Test("Load copies monthly and yearly products from SubscriptionStore")
    func loadCopiesProductsFromStore() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.products = [monthlyProduct(), yearlyProduct()]
        let model = PaywallModel(store: makeStore(commerce))
        await model.load()
        #expect(model.monthly?.displayPrice == "A$4.99")
        #expect(model.yearly?.displayPrice == "A$49.99")
        #expect(model.canPurchaseMonthly)
        #expect(model.canPurchaseYearly)
        #expect(model.activity == .idle)
    }

    @Test("Missing products do not invent prices")
    func missingProductsDoNotInventPrices() async {
        let model = PaywallModel(store: makeStore(FakeSubscriptionCommerce()))
        await model.load()
        #expect(model.monthly == nil)
        #expect(model.yearly == nil)
        #expect(!model.canPurchaseMonthly)
        #expect(!model.canPurchaseYearly)
        #expect(PaywallCopy.priceText(for: model.monthly) == nil)
    }

    @Test("Successful monthly purchase reports subscribed")
    func successfulMonthlyPurchase() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.products = [monthlyProduct()]
        commerce.entitlementsAfterPurchase = [
            SubscriptionEntitlement(productID: .monthly, expirationDate: frozenNow.addingTimeInterval(86_400), revocationDate: nil)
        ]
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseMonthly()
        #expect(commerce.purchased == [.monthly])
        #expect(model.isSubscribed)
        #expect(model.feedback == .success("You're subscribed to FreeWorkDates Pro."))
        #expect(model.activity == .idle)
    }

    @Test("Cancelled purchase stays quiet")
    func cancelledPurchaseStaysQuiet() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseOutcome = .userCancelled
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseYearly()
        #expect(commerce.purchased == [.yearly])
        #expect(model.feedback == .none)
        #expect(!model.isSubscribed)
    }

    @Test("Pending purchase shows pending feedback")
    func pendingPurchaseShowsPending() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseOutcome = .pending
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseMonthly()
        #expect(model.feedback == .pending("Your purchase is pending."))
    }

    @Test("Purchase failure shows a clean error")
    func purchaseFailureShowsError() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseError = .productUnavailable(.monthly)
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseMonthly()
        #expect(model.feedback == .failure("This plan isn't available right now."))
        #expect(!model.isSubscribed)
    }

    @Test("Restore with an entitlement succeeds")
    func restoreWithEntitlementSucceeds() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.entitlementsAfterRestore = [
            SubscriptionEntitlement(productID: .yearly, expirationDate: frozenNow.addingTimeInterval(86_400), revocationDate: nil)
        ]
        let model = PaywallModel(store: makeStore(commerce))
        await model.restorePurchases()
        #expect(commerce.restoreCount == 1)
        #expect(model.isSubscribed)
        #expect(model.feedback == .success("Purchases restored."))
    }

    @Test("Restore without an entitlement fails cleanly")
    func restoreWithoutEntitlementFails() async {
        let commerce = FakeSubscriptionCommerce()
        let model = PaywallModel(store: makeStore(commerce))
        await model.restorePurchases()
        #expect(commerce.restoreCount == 1)
        #expect(!model.isSubscribed)
        #expect(model.feedback == .failure("No subscription was found to restore."))
    }
}

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
        let suiteName = "au.freeday.tests.paywall.subscription.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SubscriptionStore(commerce: commerce, now: { frozenNow }, defaults: defaults)
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

    @Test("Verified purchase shows subscribed state even when the ledger is still empty")
    func verifiedPurchaseShowsSubscribedWhenLedgerIsEmpty() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.products = [monthlyProduct()]
        commerce.purchasedEntitlement = SubscriptionEntitlement(
            productID: .monthly,
            expirationDate: frozenNow.addingTimeInterval(86_400),
            revocationDate: nil
        )
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseMonthly()
        #expect(commerce.entitlements.isEmpty)
        #expect(model.isSubscribed)
        #expect(model.feedback == .success("You're subscribed to FreeWorkDates Pro."))
    }

    @Test("Paywall stays subscribed after a later empty entitlement refresh")
    func paywallStaysSubscribedAfterEmptyLedgerRefresh() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.products = [monthlyProduct()]
        commerce.purchasedEntitlement = SubscriptionEntitlement(
            productID: .monthly,
            expirationDate: frozenNow.addingTimeInterval(86_400),
            revocationDate: nil
        )
        let store = makeStore(commerce)
        let model = PaywallModel(store: store)
        await model.purchaseMonthly()
        #expect(model.isSubscribed)

        await store.startAndRefresh()

        #expect(model.isSubscribed)
        #expect(model.subscribedProductID == .monthly)
        #expect(PaywallCopy.headline(for: .voluntary, isSubscribed: model.isSubscribed) == "You're subscribed to FreeWorkDates Pro.")
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

    @Test("Unverified purchase does not report subscribed")
    func unverifiedPurchaseDoesNotReportSubscribed() async {
        let commerce = FakeSubscriptionCommerce()
        commerce.purchaseError = .unverified
        commerce.purchasedEntitlement = SubscriptionEntitlement(
            productID: .monthly,
            expirationDate: frozenNow.addingTimeInterval(86_400),
            revocationDate: nil
        )
        let model = PaywallModel(store: makeStore(commerce))
        await model.purchaseMonthly()
        #expect(!model.isSubscribed)
        #expect(model.feedback == .failure("We couldn't verify this purchase."))
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

    @Test("Privacy Policy URL is the published FreeWorkDates page")
    func privacyPolicyURLIsCorrect() {
        #expect(
            PaywallCopy.privacyPolicyURL.absoluteString
                == "https://arthousepaintingau.github.io/FreeDay/privacy-policy.html"
        )
    }

    @Test("Terms of Use URL is the published FreeWorkDates page")
    func termsOfUseURLIsCorrect() {
        #expect(
            PaywallCopy.termsOfUseURL.absoluteString
                == "https://arthousepaintingau.github.io/FreeDay/terms-of-use.html"
        )
    }

    @Test("Auto-renew and Apple Account management disclosures are present")
    func subscriptionDisclosuresArePresent() {
        #expect(PaywallCopy.autoRenewDisclosure == "Subscriptions automatically renew unless cancelled.")
        #expect(PaywallCopy.autoRenewDisclosure.localizedCaseInsensitiveContains("automatically renew"))
        #expect(PaywallCopy.autoRenewDisclosure.localizedCaseInsensitiveContains("cancelled"))
        #expect(
            PaywallCopy.subscriptionManagementDisclosure
                == "You can manage or cancel your subscription in your Apple Account subscription settings."
        )
        #expect(PaywallCopy.subscriptionManagementDisclosure.localizedCaseInsensitiveContains("Apple Account"))
        #expect(PaywallCopy.subscriptionManagementDisclosure.localizedCaseInsensitiveContains("cancel"))
    }

    @Test("Paywall still names monthly and yearly plans without changing Product IDs")
    func monthlyAndYearlyPlansKeepExistingProductIDs() {
        #expect(PaywallCopy.planTitle(for: .monthly) == "Monthly")
        #expect(PaywallCopy.planTitle(for: .yearly) == "Yearly")
        #expect(PaywallCopy.billingPeriod(for: .monthly) == "Billed monthly")
        #expect(PaywallCopy.billingPeriod(for: .yearly) == "Billed yearly")
        #expect(SubscriptionProductID.monthly.rawValue == "app.freeday.FreeDay.monthly")
        #expect(SubscriptionProductID.yearly.rawValue == "app.freeday.FreeDay.yearly")
        #expect(PaywallCopy.priceText(for: monthlyProduct(price: "A$9.99")) == "A$9.99")
        #expect(PaywallCopy.priceText(for: yearlyProduct(price: "A$79.99")) == "A$79.99")
    }

    @Test("Close is hidden on the locked paywall and kept on the Settings paywall")
    func closeButtonOnlyOnVoluntaryPaywall() {
        #expect(!PaywallCopy.showsCloseButton(for: .expiredTrial))
        #expect(PaywallCopy.showsCloseButton(for: .voluntary))
    }

    @Test("Restore Purchases still reports success and empty results")
    func restorePurchasesRemainsAvailable() {
        #expect(PaywallCopy.restoreFeedback(isSubscribed: true) == .success("Purchases restored."))
        #expect(PaywallCopy.restoreFeedback(isSubscribed: false) == .failure("No subscription was found to restore."))
    }
}

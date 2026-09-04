import Foundation
import Observation

/// UI state for the Pro paywall. Calls `SubscriptionStore`; does not talk to StoreKit itself.
@MainActor
@Observable
final class PaywallModel {
    private let store: SubscriptionStore

    var activity: PaywallActivity = .idle
    var feedback: PaywallFeedback = .none
    var monthly: LoadedSubscriptionProduct?
    var yearly: LoadedSubscriptionProduct?

    var isBusy: Bool {
        activity != .idle
    }

    var canPurchaseMonthly: Bool {
        PaywallCopy.priceText(for: monthly) != nil && !isBusy
    }

    var canPurchaseYearly: Bool {
        PaywallCopy.priceText(for: yearly) != nil && !isBusy
    }

    var isSubscribed: Bool {
        store.isSubscribed
    }

    var subscribedProductID: SubscriptionProductID? {
        if case .subscribed(let productID, _) = store.status {
            return productID
        }
        return nil
    }

    init(store: SubscriptionStore) {
        self.store = store
        monthly = store.monthlyProduct
        yearly = store.yearlyProduct
    }

    func load() async {
        feedback = .none
        activity = .loading
        await store.startAndRefresh()
        monthly = store.monthlyProduct
        yearly = store.yearlyProduct
        activity = .idle
    }

    func purchaseMonthly() async {
        await purchase(.monthly)
    }

    func purchaseYearly() async {
        await purchase(.yearly)
    }

    func restorePurchases() async {
        guard !isBusy else { return }
        feedback = .none
        activity = .restoring
        do {
            try await store.restorePurchases()
            feedback = PaywallCopy.restoreFeedback(isSubscribed: store.isSubscribed)
        } catch {
            feedback = PaywallCopy.failure(error)
        }
        activity = .idle
    }

    private func purchase(_ id: SubscriptionProductID) async {
        guard !isBusy else { return }
        feedback = .none
        activity = .purchasing(id)
        do {
            let outcome = try await purchaseAction(id)
            feedback = PaywallCopy.purchaseFeedback(outcome, isSubscribed: store.isSubscribed)
        } catch {
            feedback = PaywallCopy.failure(error)
        }
        activity = .idle
    }

    private func purchaseAction(_ id: SubscriptionProductID) async throws -> PurchaseOutcome {
        switch id {
        case .monthly:
            try await store.purchaseMonthly()
        case .yearly:
            try await store.purchaseYearly()
        }
    }
}

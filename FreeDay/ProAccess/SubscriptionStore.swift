import Foundation
import Observation

/// Isolated StoreKit 2 subscription manager.
///
/// Does not present UI, gate features, or change the 30-day trial.
/// `isSubscribed` is the StoreKit input to `ProAccessStore.hasFullAccess(isSubscribed:)`.
@MainActor
@Observable
final class SubscriptionStore {
    /// Retained for app launch so `Transaction.updates` keeps running.
    static let shared = SubscriptionStore()

    private let commerce: any SubscriptionCommerce
    private let now: @Sendable () -> Date
    private var updatesTask: Task<Void, Never>?

    private(set) var products: [LoadedSubscriptionProduct] = []
    private(set) var status: SubscriptionStatus = .notSubscribed

    /// Seam for `ProAccessStore.hasFullAccess`.
    var isSubscribed: Bool {
        if case .subscribed = status { return true }
        return false
    }

    var monthlyProduct: LoadedSubscriptionProduct? {
        products.first(where: { $0.id == .monthly })
    }

    var yearlyProduct: LoadedSubscriptionProduct? {
        products.first(where: { $0.id == .yearly })
    }

    init(
        commerce: any SubscriptionCommerce = StoreKitSubscriptionCommerce(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.commerce = commerce
        self.now = now
    }

    func start() {
        Task { await startAndRefresh() }
    }

    func startAndRefresh() async {
        listenForUpdatesIfNeeded()
        await commerce.finishUnfinishedVerifiedTransactions()
        await refreshProducts()
        await refreshEntitlements()
    }

    func purchaseMonthly() async throws -> PurchaseOutcome {
        try await purchase(.monthly)
    }

    func purchaseYearly() async throws -> PurchaseOutcome {
        try await purchase(.yearly)
    }

    func restorePurchases() async throws {
        try await commerce.restore()
        await refreshEntitlements()
    }

    private func purchase(_ id: SubscriptionProductID) async throws -> PurchaseOutcome {
        let (outcome, entitlement) = try await commerce.purchase(id)
        if outcome == .success {
            applyVerifiedPurchaseEntitlement(entitlement)
            await refreshEntitlements()
            if !isSubscribed {
                applyVerifiedPurchaseEntitlement(entitlement)
            }
        }
        return outcome
    }

    private func applyVerifiedPurchaseEntitlement(_ entitlement: SubscriptionEntitlement?) {
        guard let entitlement else { return }
        let next = Self.status(from: [entitlement], now: now())
        if next != status {
            status = next
        }
    }

    private func listenForUpdatesIfNeeded() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in self.commerce.transactionUpdates() {
                await self.refreshEntitlements()
            }
        }
    }

    private func refreshProducts() async {
        let loaded: [LoadedSubscriptionProduct]
        do {
            loaded = try await commerce.loadProducts()
        } catch {
            loaded = []
        }
        if loaded != products {
            products = loaded
        }
    }

    private func refreshEntitlements() async {
        let entitlements = await commerce.currentEntitlements()
        let next = Self.status(from: entitlements, now: now())
        if next != status {
            status = next
        }
    }

    static func status(
        from entitlements: [SubscriptionEntitlement],
        now: Date
    ) -> SubscriptionStatus {
        let active = entitlements.filter { $0.isActive(at: now) }
        guard let best = active.max(by: {
            ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture)
        }) else {
            return .notSubscribed
        }
        return .subscribed(productID: best.productID, expirationDate: best.expirationDate)
    }
}

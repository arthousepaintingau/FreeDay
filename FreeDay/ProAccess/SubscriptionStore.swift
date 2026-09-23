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
    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    /// Last verified purchase. `Transaction.currentEntitlements` can stay empty on TestFlight
    /// immediately after buy; this grant must not be erased by that stale ledger.
    private var verifiedPurchaseEntitlement: SubscriptionEntitlement?

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
        now: @escaping @Sendable () -> Date = { Date() },
        defaults: UserDefaults = .standard
    ) {
        self.commerce = commerce
        self.now = now
        self.defaults = defaults
        restorePersistedFallbackIfNeeded()
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
            rememberVerifiedPurchase(entitlement)
            applyVerifiedPurchaseEntitlement(entitlement)
            await refreshEntitlements()
        }
        return outcome
    }

    private func rememberVerifiedPurchase(_ entitlement: SubscriptionEntitlement?) {
        guard let entitlement, entitlement.isActive(at: now()) else { return }
        verifiedPurchaseEntitlement = entitlement
        VerifiedSubscriptionPersistence.save(entitlement, to: defaults, now: now())
    }

    private func restorePersistedFallbackIfNeeded() {
        guard let persisted = VerifiedSubscriptionPersistence.loadActive(from: defaults, now: now()) else {
            return
        }
        verifiedPurchaseEntitlement = persisted
        status = Self.status(from: [persisted], now: now())
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
        let next = resolvedStatus(ledgerEntitlements: entitlements)
        if next != status {
            status = next
        }
    }

    /// A. Active StoreKit ledger wins and replaces the local fallback.
    /// B. An empty ledger keeps a still-active verified fallback (in-memory or persisted).
    /// C. An explicitly inactive/revoked/expired ledger clears that fallback.
    private func resolvedStatus(ledgerEntitlements: [SubscriptionEntitlement]) -> SubscriptionStatus {
        let ledgerStatus = Self.status(from: ledgerEntitlements, now: now())
        if case .subscribed(let productID, let expirationDate) = ledgerStatus {
            rememberVerifiedPurchase(
                SubscriptionEntitlement(productID: productID, expirationDate: expirationDate, revocationDate: nil)
            )
            return ledgerStatus
        }
        if !ledgerEntitlements.isEmpty {
            verifiedPurchaseEntitlement = nil
            VerifiedSubscriptionPersistence.clear(from: defaults)
            return .notSubscribed
        }
        if let verified = verifiedPurchaseEntitlement, verified.isActive(at: now()) {
            return Self.status(from: [verified], now: now())
        }
        if verifiedPurchaseEntitlement != nil {
            verifiedPurchaseEntitlement = nil
            VerifiedSubscriptionPersistence.clear(from: defaults)
        }
        return ledgerStatus
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

/// Smallest local copy of a previously verified entitlement. Not proof of a new purchase.
enum VerifiedSubscriptionPersistence {
    static let key = "subscription.verifiedEntitlement"

    struct Record: Codable, Equatable {
        var productID: String
        var expirationDate: Date?
        var revocationDate: Date?
    }

    static func save(_ entitlement: SubscriptionEntitlement, to defaults: UserDefaults, now: Date) {
        guard entitlement.isActive(at: now) else { return }
        guard SubscriptionProductID(rawValue: entitlement.productID.rawValue) != nil else { return }
        let record = Record(
            productID: entitlement.productID.rawValue,
            expirationDate: entitlement.expirationDate,
            revocationDate: entitlement.revocationDate
        )
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    static func loadActive(from defaults: UserDefaults, now: Date) -> SubscriptionEntitlement? {
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let record = try? JSONDecoder().decode(Record.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard let productID = SubscriptionProductID(rawValue: record.productID) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        let entitlement = SubscriptionEntitlement(
            productID: productID,
            expirationDate: record.expirationDate,
            revocationDate: record.revocationDate
        )
        guard entitlement.isActive(at: now) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return entitlement
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: key)
    }
}

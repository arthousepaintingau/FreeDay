import Foundation
import StoreKit

protocol SubscriptionCommerce: Sendable {
    func loadProducts() async throws -> [LoadedSubscriptionProduct]
    func purchase(_ id: SubscriptionProductID) async throws -> PurchaseOutcome
    func currentEntitlements() async -> [SubscriptionEntitlement]
    func transactionUpdates() -> AsyncStream<Void>
    func restore() async throws
    func finishUnfinishedVerifiedTransactions() async
}

/// StoreKit 2 adapter. Isolated so tests can fake commerce without App Store Connect.
struct StoreKitSubscriptionCommerce: SubscriptionCommerce {
    func loadProducts() async throws -> [LoadedSubscriptionProduct] {
        let storeProducts = try await Product.products(for: SubscriptionProductID.allIDs)
        return SubscriptionProductID.allCases.compactMap { id in
            guard let product = storeProducts.first(where: { $0.id == id.rawValue }) else {
                return nil
            }
            return LoadedSubscriptionProduct(
                id: id,
                displayName: product.displayName,
                displayPrice: product.displayPrice
            )
        }
    }

    func purchase(_ id: SubscriptionProductID) async throws -> PurchaseOutcome {
        let storeProducts = try await Product.products(for: [id.rawValue])
        guard let product = storeProducts.first else {
            throw SubscriptionError.productUnavailable(id)
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func currentEntitlements() async -> [SubscriptionEntitlement] {
        var entitlements: [SubscriptionEntitlement] = []
        for await verification in Transaction.currentEntitlements {
            if let entitlement = Self.entitlement(fromVerified: verification) {
                entitlements.append(entitlement)
            }
        }
        return entitlements
    }

    func transactionUpdates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await verification in Transaction.updates {
                    if let transaction = try? Self.verified(verification) {
                        await transaction.finish()
                        continuation.yield()
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func restore() async throws {
        try await AppStore.sync()
    }

    func finishUnfinishedVerifiedTransactions() async {
        for await verification in Transaction.unfinished {
            if let transaction = try? Self.verified(verification) {
                await transaction.finish()
            }
        }
    }

    static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw SubscriptionError.unverified
        }
    }

    private static func entitlement(
        fromVerified result: VerificationResult<Transaction>
    ) -> SubscriptionEntitlement? {
        guard let transaction = try? verified(result) else { return nil }
        return SubscriptionEntitlement(transaction: transaction)
    }
}

extension SubscriptionEntitlement {
    init?(transaction: Transaction) {
        guard let productID = SubscriptionProductID(rawValue: transaction.productID) else {
            return nil
        }
        self.init(
            productID: productID,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate
        )
    }
}

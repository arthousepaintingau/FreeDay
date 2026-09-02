import Foundation

enum SubscriptionProductID: String, CaseIterable, Sendable {
    case monthly = "app.freeday.FreeDay.monthly"
    case yearly = "app.freeday.FreeDay.yearly"

    static var allIDs: [String] {
        allCases.map(\.rawValue)
    }
}

enum SubscriptionStatus: Equatable, Sendable {
    case notSubscribed
    case subscribed(productID: SubscriptionProductID, expirationDate: Date?)
}

enum PurchaseOutcome: Equatable, Sendable {
    case success
    case userCancelled
    case pending
}

enum SubscriptionError: Error, Equatable {
    case productUnavailable(SubscriptionProductID)
    case unverified
}

struct LoadedSubscriptionProduct: Equatable, Sendable {
    var id: SubscriptionProductID
    var displayName: String
    var displayPrice: String
}

struct SubscriptionEntitlement: Equatable, Sendable {
    var productID: SubscriptionProductID
    var expirationDate: Date?
    var revocationDate: Date?

    func isActive(at now: Date) -> Bool {
        if revocationDate != nil { return false }
        if let expirationDate { return expirationDate > now }
        return true
    }
}

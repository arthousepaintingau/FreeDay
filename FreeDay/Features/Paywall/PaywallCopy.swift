import Foundation

enum PaywallActivity: Equatable, Sendable {
    case idle
    case loading
    case purchasing(SubscriptionProductID)
    case restoring
}

enum PaywallFeedback: Equatable, Sendable {
    case none
    case success(String)
    case failure(String)
    case pending(String)
}

enum PaywallCopy {
    static var headline: String {
        String(localized: "Your 30-day free access has ended", comment: "Paywall headline")
    }

    static var explanation: String {
        String(
            localized: "A Pro subscription is required to continue using FreeDay.",
            comment: "Paywall explanation"
        )
    }

    static func planTitle(for id: SubscriptionProductID) -> String {
        switch id {
        case .monthly:
            String(localized: "Monthly", comment: "Monthly subscription plan")
        case .yearly:
            String(localized: "Yearly", comment: "Yearly subscription plan")
        }
    }

    static func planTitle(for product: LoadedSubscriptionProduct) -> String {
        let name = product.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? planTitle(for: product.id) : name
    }

    /// StoreKit localized price only. Never substitutes a hardcoded amount.
    static func priceText(for product: LoadedSubscriptionProduct?) -> String? {
        guard let product else { return nil }
        let price = product.displayPrice.trimmingCharacters(in: .whitespacesAndNewlines)
        return price.isEmpty ? nil : price
    }

    static func purchaseFeedback(
        _ outcome: PurchaseOutcome,
        isSubscribed: Bool
    ) -> PaywallFeedback {
        switch outcome {
        case .success:
            if isSubscribed {
                return .success(String(localized: "You're subscribed to FreeDay Pro.", comment: "Paywall purchase success"))
            }
            return .failure(String(localized: "We couldn't confirm this subscription.", comment: "Paywall purchase unverified success"))
        case .userCancelled:
            return .none
        case .pending:
            return .pending(String(localized: "Your purchase is pending.", comment: "Paywall purchase pending"))
        }
    }

    static func restoreFeedback(isSubscribed: Bool) -> PaywallFeedback {
        if isSubscribed {
            return .success(String(localized: "Purchases restored.", comment: "Paywall restore success"))
        }
        return .failure(String(localized: "No subscription was found to restore.", comment: "Paywall restore empty"))
    }

    static func failure(_ error: Error) -> PaywallFeedback {
        if let error = error as? SubscriptionError {
            switch error {
            case .productUnavailable:
                return .failure(String(localized: "This plan isn't available right now.", comment: "Paywall missing product"))
            case .unverified:
                return .failure(String(localized: "We couldn't verify this purchase.", comment: "Paywall unverified purchase"))
            }
        }
        return .failure(String(localized: "Something went wrong. Please try again.", comment: "Paywall generic failure"))
    }
}

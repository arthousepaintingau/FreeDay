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

enum PaywallPresentation: Equatable, Sendable {
    /// Mandatory lock after the 30-day initial access period ends.
    case expiredTrial
    /// Pro screen opened from Settings while the app is already unlocked.
    case voluntary
}

enum PaywallCopy {
    static var headline: String {
        headline(for: .expiredTrial, isSubscribed: false)
    }

    static var explanation: String {
        explanation(for: .expiredTrial, isSubscribed: false)
    }

    static func headline(for presentation: PaywallPresentation, isSubscribed: Bool) -> String {
        if isSubscribed {
            return String(localized: "You're subscribed to FreeWorkDates Pro.", comment: "Paywall headline when already subscribed")
        }
        switch presentation {
        case .expiredTrial:
            return String(localized: "Your 30-day free access has ended", comment: "Paywall headline")
        case .voluntary:
            return String(localized: "Upgrade to FreeWorkDates Pro", comment: "Paywall headline from Settings during trial")
        }
    }

    static func explanation(for presentation: PaywallPresentation, isSubscribed: Bool) -> String {
        if isSubscribed {
            return String(
                localized: "Your subscription is active. Restore Purchases can confirm it on this Apple Account.",
                comment: "Paywall explanation when already subscribed"
            )
        }
        switch presentation {
        case .expiredTrial:
            return String(
                localized: "A Pro subscription is required to continue using FreeWorkDates.",
                comment: "Paywall explanation"
            )
        case .voluntary:
            return String(
                localized: "Subscribe now for uninterrupted full access after your 30-day initial access period.",
                comment: "Paywall explanation from Settings during trial"
            )
        }
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
                return .success(String(localized: "You're subscribed to FreeWorkDates Pro.", comment: "Paywall purchase success"))
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

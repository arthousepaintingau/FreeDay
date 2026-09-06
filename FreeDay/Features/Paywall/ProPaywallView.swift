import SwiftUI

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: PaywallModel
    private let presentation: PaywallPresentation

    init(
        presentation: PaywallPresentation = .expiredTrial,
        store: SubscriptionStore = .shared
    ) {
        self.presentation = presentation
        _model = State(initialValue: PaywallModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        Text(PaywallCopy.headline(for: presentation, isSubscribed: model.isSubscribed))
                            .font(FreeDayFont.title)
                            .foregroundStyle(FreeDayColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("paywall-headline")

                        Text(PaywallCopy.explanation(for: presentation, isSubscribed: model.isSubscribed))
                            .font(FreeDayFont.body)
                            .foregroundStyle(FreeDayColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if model.activity == .loading {
                        ProgressView()
                            .tint(FreeDayColor.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, FreeDaySpacing.xl)
                            .accessibilityIdentifier("paywall-loading")
                    } else {
                        plans
                    }

                    SecondaryButton(
                        title: String(localized: "Restore Purchases", comment: "Paywall restore"),
                        action: {
                            Task { await model.restorePurchases() }
                        }
                    )
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("paywall-restore")

                    feedback
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.lg)
                .freeDayContentWidth()
            }
            .background(FreeDayColor.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "FreeWorkDates Pro", comment: "Paywall title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close", comment: "Close paywall")) {
                        dismiss()
                    }
                    .disabled(model.activity == .purchasing(.monthly) || model.activity == .purchasing(.yearly) || model.activity == .restoring)
                }
            }
        }
        .task {
            await model.load()
        }
    }

    @ViewBuilder
    private var plans: some View {
        if model.monthly == nil && model.yearly == nil {
            FreeDayCard {
                Text(String(localized: "Plans aren't available right now.", comment: "Paywall missing products"))
                    .font(FreeDayFont.body)
                    .foregroundStyle(FreeDayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier("paywall-unavailable")
        } else {
            planCard(product: model.monthly, id: .monthly)
            planCard(product: model.yearly, id: .yearly)
        }
    }

    @ViewBuilder
    private func planCard(product: LoadedSubscriptionProduct?, id: SubscriptionProductID) -> some View {
        let price = PaywallCopy.priceText(for: product)
        let purchasing = model.activity == .purchasing(id)

        FreeDayCard {
            VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
                FreeDaySectionHeader(title: PaywallCopy.planTitle(for: id))

                if let product {
                    Text(PaywallCopy.planTitle(for: product))
                        .font(FreeDayFont.headline)
                        .foregroundStyle(FreeDayColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let price {
                    Text(price)
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.ink)
                        .accessibilityIdentifier(id == .monthly ? "paywall-monthly-price" : "paywall-yearly-price")
                } else {
                    Text(String(localized: "Unavailable", comment: "Paywall plan missing price"))
                        .font(FreeDayFont.body)
                        .foregroundStyle(FreeDayColor.muted)
                }

                if model.isSubscribed {
                    Text(
                        model.subscribedProductID == id
                            ? String(localized: "Current plan", comment: "Paywall current subscribed plan")
                            : String(localized: "Included in FreeWorkDates Pro", comment: "Paywall other plan while subscribed")
                    )
                    .font(FreeDayFont.body)
                    .foregroundStyle(FreeDayColor.muted)
                    .accessibilityIdentifier(id == .monthly ? "paywall-monthly-status" : "paywall-yearly-status")
                } else {
                    PrimaryButton(
                        title: purchasing
                            ? String(localized: "Purchasing…", comment: "Paywall purchasing")
                            : String(localized: "Subscribe", comment: "Paywall subscribe"),
                        isEnabled: id == .monthly ? model.canPurchaseMonthly : model.canPurchaseYearly,
                        action: {
                            Task {
                                if id == .monthly {
                                    await model.purchaseMonthly()
                                } else {
                                    await model.purchaseYearly()
                                }
                            }
                        }
                    )
                    .accessibilityIdentifier(id == .monthly ? "paywall-subscribe-monthly" : "paywall-subscribe-yearly")
                }
            }
        }
    }

    @ViewBuilder
    private var feedback: some View {
        switch model.feedback {
        case .none:
            EmptyView()
        case .success(let message):
            Text(message)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.free)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall-success")
        case .failure(let message):
            Text(message)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.booked)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall-error")
        case .pending(let message):
            Text(message)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.muted)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("paywall-pending")
        }
    }
}

#Preview {
    ProPaywallView()
}

import SwiftUI

struct SettingsView: View {
    @Environment(WorkWeekStore.self) private var store
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(
                        title: String(localized: "Working Days", comment: "Settings section")
                    )
                    Text(String(localized: "Choose the days you normally work.", comment: "Working days explanation"))
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FreeDayCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(WorkWeekday.mondayFirst.enumerated()), id: \.element.id) { index, day in
                            if index > 0 {
                                Divider()
                                    .background(FreeDayColor.hairline)
                            }
                            dayToggle(day)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(
                        title: String(localized: "FreeWorkDates Pro", comment: "Settings section")
                    )
                    Text(proSectionCaption)
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FreeDayCard(padding: 0) {
                    Button {
                        showPaywall = true
                    } label: {
                        settingsRowLabel(proRowTitle, showsExternalIndicator: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings-freeday-pro")
                    .accessibilityHint(proRowHint)
                }

                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(
                        title: String(localized: "Legal", comment: "Settings section")
                    )
                    Text(String(localized: "Opens in Safari.", comment: "Legal links explanation"))
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                FreeDayCard(padding: 0) {
                    VStack(spacing: 0) {
                        legalLink(
                            title: String(localized: "Privacy Policy", comment: "Settings legal link"),
                            url: Self.privacyPolicyURL,
                            identifier: "settings-privacy-policy"
                        )
                        Divider()
                            .background(FreeDayColor.hairline)
                        legalLink(
                            title: String(localized: "Terms of Use", comment: "Settings legal link"),
                            url: Self.termsOfUseURL,
                            identifier: "settings-terms-of-use"
                        )
                    }
                }
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.lg)
            .padding(.bottom, FreeDaySpacing.xl)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "Settings", comment: "Settings screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            ProPaywallView(presentation: .voluntary)
        }
    }

    private static let privacyPolicyURL = URL(string: "https://arthousepaintingau.github.io/FreeDay/privacy-policy.html")!
    private static let termsOfUseURL = URL(string: "https://arthousepaintingau.github.io/FreeDay/terms-of-use.html")!

    private var isSubscribed: Bool {
        subscriptions.isSubscribed
    }

    private var proRowTitle: String {
        if isSubscribed {
            String(localized: "View FreeWorkDates Pro", comment: "Settings row when already subscribed")
        } else {
            String(localized: "Upgrade to FreeWorkDates Pro", comment: "Settings row during trial")
        }
    }

    private var proSectionCaption: String {
        if isSubscribed {
            String(
                localized: "View your FreeWorkDates Pro plans. Restore Purchases is available on the next screen.",
                comment: "FreeWorkDates Pro settings explanation when subscribed"
            )
        } else {
            String(
                localized: "Optional during your 30-day access period. View plans whenever you like. Restore Purchases is available on the next screen.",
                comment: "FreeWorkDates Pro settings explanation during trial"
            )
        }
    }

    private var proRowHint: String {
        String(
            localized: "Opens FreeWorkDates Pro plans and Restore Purchases",
            comment: "VoiceOver hint for FreeWorkDates Pro settings row"
        )
    }

    private func dayToggle(_ day: WorkWeekday) -> some View {
        Toggle(isOn: binding(for: day)) {
            Text(day.name)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(FreeDayColor.brand)
        .disabled(!day.isConfigurable)
        .padding(.horizontal, FreeDaySpacing.md)
        .padding(.vertical, FreeDaySpacing.sm)
        .frame(minHeight: FreeDaySpacing.touch)
        .accessibilityIdentifier(day.accessibilityIdentifier)
        .accessibilityHint(hint(for: day))
    }

    private func legalLink(title: String, url: URL, identifier: String) -> some View {
        Link(destination: url) {
            settingsRowLabel(title, showsExternalIndicator: true)
        }
        .accessibilityIdentifier(identifier)
    }

    private func settingsRowLabel(_ title: String, showsExternalIndicator: Bool) -> some View {
        HStack {
            Text(title)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: showsExternalIndicator ? "arrow.up.right" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(FreeDayColor.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, FreeDaySpacing.md)
        .padding(.vertical, FreeDaySpacing.sm)
        .frame(minHeight: FreeDaySpacing.touch)
        .contentShape(Rectangle())
    }

    private func binding(for day: WorkWeekday) -> Binding<Bool> {
        switch day {
        case .saturday:
            return Binding(
                get: { store.worksSaturday },
                set: { store.worksSaturday = $0 }
            )
        case .sunday:
            return Binding(
                get: { store.worksSunday },
                set: { store.worksSunday = $0 }
            )
        default:
            return .constant(true)
        }
    }

    private func hint(for day: WorkWeekday) -> String {
        if day.isConfigurable {
            return String(
                localized: "Enabled days are days you are available to work",
                comment: "VoiceOver hint for weekend working-day toggle"
            )
        }
        return String(
            localized: "Weekdays are always working days",
            comment: "VoiceOver hint for fixed weekday"
        )
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(WorkWeekStore.self) private var store

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
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.lg)
            .padding(.bottom, FreeDaySpacing.xl)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "Settings", comment: "Settings screen title"))
        .navigationBarTitleDisplayMode(.inline)
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

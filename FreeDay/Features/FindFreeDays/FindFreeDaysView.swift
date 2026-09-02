import SwiftData
import SwiftUI

struct FindFreeDaysView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var projects: [Project]

    var onChooseSlot: (FreeSlot, Int) -> Void

    @State private var duration = 3
    @State private var result: AvailabilitySearchResult?
    @State private var hasSearched = false

    var body: some View {
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                    Text(String(localized: "How many days do you need?", comment: "Find free days prompt"))
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    FreeDayCard {
                        DayStepper(days: $duration, unitPlacement: .value)
                    }
                    .accessibilityIdentifier("find-free-days-duration")

                    if hasSearched, let result {
                        results(result, formatters: formatters)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.lg)
                .animation(Motion.animation(reduceMotion), value: hasSearched)
                .animation(Motion.animation(reduceMotion), value: result?.slots.map(\.start))
                .freeDayContentWidth()
            }
            .background(FreeDayColor.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "Find Free Days", comment: "Find free days title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close", comment: "Close find free days")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: String(localized: "Find Available Days", comment: "Run availability search"),
                    systemImage: "magnifyingglass",
                    action: search
                )
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.xs)
                .background(FreeDayColor.canvas.opacity(0.96))
                .accessibilityIdentifier("find-free-days-search")
                .freeDayContentWidth()
            }
            .onChange(of: duration) { _, _ in
                if hasSearched {
                    hasSearched = false
                    result = nil
                }
            }
        }
    }

    private func search() {
        let snapshots = projects.map(\.snapshot)
        result = environment.availabilitySearch.findSlots(
            duration: duration,
            from: .now,
            projects: snapshots
        )
        hasSearched = true
        FreeDayHaptics.light()
    }

    @ViewBuilder
    private func results(_ result: AvailabilitySearchResult, formatters: DateFormatters) -> some View {
        if result.isEmpty {
            FreeDayCard {
                FreeDayEmptyState(
                    title: PersonalityCopy.fullyBooked,
                    message: PersonalityCopy.noSlot(horizonDays: result.horizonDays),
                    mascot: .booked
                )
            }
            .accessibilityIdentifier("find-free-days-empty")
        } else if let next = result.next {
            VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                nextAvailableCard(next, formatters: formatters)

                if !result.others.isEmpty {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        FreeDaySectionHeader(title: String(localized: "Other options", comment: "Additional free slots"))
                        PersonalityLine(text: PersonalityCopy.gotRoom, style: .caption)

                        ForEach(Array(result.others.enumerated()), id: \.element.id) { index, slot in
                            otherOptionCard(slot, formatters: formatters)
                                .accessibilityIdentifier("find-free-days-other-\(index)")
                        }
                    }
                }
            }
        }
    }

    private func nextAvailableCard(_ slot: FreeSlot, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            FreeDaySectionHeader(title: String(localized: "Next available", comment: "First free slot heading"))

            Button {
                FreeDayHaptics.selection()
                onChooseSlot(slot, duration)
            } label: {
                FreeDayCard(emphasize: .free) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                        AvailabilityHero(
                            kind: .free,
                            title: String(localized: "YES — YOU'RE FREE!", comment: "Find free days answer")
                        )
                        HStack(spacing: FreeDaySpacing.xs) {
                            StatusBadge(availability: .free)
                            Text(PersonalityCopy.perfectFit)
                                .font(FreeDayFont.headline)
                                .foregroundStyle(FreeDayColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        slotEndpoints(slot, formatters: formatters, prominent: true)

                        Text(
                            String(
                                localized: "\(slot.durationWorkingDays) working days",
                                comment: "Slot duration"
                            )
                        )
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                        .accessibilityElement()
                        .accessibilityLabel(
                            String(
                                localized: "\(slot.durationWorkingDays) working days",
                                comment: "Slot duration"
                            )
                        )
                        .accessibilityAddTraits(.isStaticText)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("find-free-days-next-slot")
            .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
            .accessibilityHint(String(localized: "Opens Add Project with this start date and duration", comment: "Choose slot hint"))
        }
    }

    private func otherOptionCard(_ slot: FreeSlot, formatters: DateFormatters) -> some View {
        Button {
            FreeDayHaptics.selection()
            onChooseSlot(slot, duration)
        } label: {
            FreeDayCard(padding: FreeDaySpacing.md) {
                HStack(alignment: .center, spacing: FreeDaySpacing.sm) {
                    StatusBadge(availability: .free)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatters.fullDate(slot.start))
                            .font(FreeDayFont.headline)
                            .foregroundStyle(FreeDayColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(
                            String(
                                localized: "to \(formatters.fullDate(slot.end))",
                                comment: "Other slot finish date"
                            )
                        )
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: FreeDaySpacing.xs)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(FreeDayColor.muted)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
        .accessibilityHint(String(localized: "Opens Add Project with this start date and duration", comment: "Choose slot hint"))
    }

    private func slotEndpoints(_ slot: FreeSlot, formatters: DateFormatters, prominent: Bool) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
            endpoint(
                title: String(localized: "You can start", comment: "Slot start heading"),
                date: slot.start,
                formatters: formatters,
                prominent: prominent
            )
            Image(systemName: "arrow.down")
                .font(.body.weight(.semibold))
                .foregroundStyle(FreeDayColor.muted)
                .accessibilityHidden(true)
            endpoint(
                title: String(localized: "You’ll finish", comment: "Slot end heading"),
                date: slot.end,
                formatters: formatters,
                prominent: prominent
            )
        }
    }

    private func endpoint(
        title: String,
        date: Date,
        formatters: DateFormatters,
        prominent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FreeDaySectionHeader(title: title)
            Text(formatters.weekdayFull(date))
                .font(prominent ? FreeDayFont.display : FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)
            Text(formatters.dayAndMonth(date))
                .font(prominent ? FreeDayFont.title : FreeDayFont.body)
                .foregroundStyle(FreeDayColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func slotAccessibility(_ slot: FreeSlot, formatters: DateFormatters) -> String {
        "\(formatters.fullDate(slot.start)) to \(formatters.fullDate(slot.end)), \(slot.durationWorkingDays) working days"
    }
}

import SwiftData
import SwiftUI

struct QuickCheckView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var projects: [Project]

    var onUseDates: (FreeSlot, Int) -> Void

    @State private var duration = QuickCheck.defaultDuration
    @State private var fromDate = Date()
    @State private var horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
    @State private var selectedStart: Date?
    @State private var showFromPicker = false
    @State private var specificDateMode = false
    @State private var specificDate = Date()
    @State private var showSpecificPicker = false

    var body: some View {
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)
        let calendar = environment.workingCalendar.calendar
        let snapshots = projects.map(\.snapshot)
        let check = QuickCheck(from: fromDate, duration: duration, horizonDays: horizonDays)
        let result = check.result(search: environment.availabilitySearch, projects: snapshots)
        let selected = selectedSlot(in: result, calendar: calendar)
        let specific = SpecificDateCheck(
            requestedDate: specificDate,
            duration: duration,
            horizonDays: horizonDays
        )
        let specificResult = specific.evaluate(
            engine: environment.scheduling,
            search: environment.availabilitySearch,
            projects: snapshots
        )

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                        controls(formatters: formatters, calendar: calendar)
                            .id("quick-check-controls")

                        if specificDateMode {
                            specificResults(specificResult, formatters: formatters)
                        } else {
                            results(
                                result,
                                selected: selected,
                                personality: check.message(for: result),
                                formatters: formatters
                            )
                        }
                    }
                    .padding(.horizontal, FreeDaySpacing.screen)
                    .padding(.vertical, FreeDaySpacing.lg)
                    .freeDayContentWidth()
                }
                .background(FreeDayColor.canvas.ignoresSafeArea())
                .navigationTitle(String(localized: "Quick Check", comment: "Quick check title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Close", comment: "Close quick check")) {
                            dismiss()
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if specificDateMode {
                        specificActions(specificResult)
                    } else {
                        actions(selected: selected, proxy: proxy)
                    }
                }
                .onChange(of: duration) { _, _ in
                    selectedStart = nil
                    horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
                }
                .onChange(of: fromDate) { _, _ in
                    selectedStart = nil
                    horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
                }
                .onChange(of: specificDate) { _, new in
                    let snapped = environment.workingCalendar.nextWorkingDay(onOrAfter: new)
                    if !calendar.isDate(snapped, inSameDayAs: new) {
                        specificDate = snapped
                    }
                    horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
                }
            }
        }
    }

    @ViewBuilder
    private func controls(formatters: DateFormatters, calendar: Calendar) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
            Text(String(localized: "How long is the job?", comment: "Quick check prompt"))
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            FreeDayCard {
                DayStepper(days: $duration, range: QuickCheck.minDuration...QuickCheck.maxDuration, unitPlacement: .value)
            }
            .accessibilityIdentifier("quick-check-duration")

            if specificDateMode {
                specificDateControls(formatters: formatters)
            } else {
                fromControls(formatters: formatters, calendar: calendar)
            }
        }
    }

    @ViewBuilder
    private func fromControls(formatters: DateFormatters, calendar: Calendar) -> some View {
        Button {
            showFromPicker.toggle()
        } label: {
            FreeDayCard(padding: FreeDaySpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        FreeDaySectionHeader(title: String(localized: "From", comment: "Quick check start date"))
                        Text(fromLabel(formatters: formatters, calendar: calendar))
                            .font(FreeDayFont.headline)
                            .foregroundStyle(FreeDayColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: FreeDaySpacing.xs)
                    Image(systemName: "calendar")
                        .foregroundStyle(FreeDayColor.brand)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("quick-check-from")
        .accessibilityLabel(
            String(
                localized: "Search from \(fromLabel(formatters: formatters, calendar: calendar))",
                comment: "VoiceOver for quick check start date"
            )
        )

        if showFromPicker {
            DatePicker(
                String(localized: "From date", comment: "Quick check date picker"),
                selection: $fromDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(FreeDayColor.brand)
            .accessibilityIdentifier("quick-check-from-picker")
        }

        Button {
            specificDateMode = true
            specificDate = environment.workingCalendar.nextWorkingDay(onOrAfter: fromDate)
            showSpecificPicker = false
            showFromPicker = false
            horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
            FreeDayHaptics.selection()
        } label: {
            Text(String(localized: "Check a Specific Date", comment: "Open specific date check"))
                .font(FreeDayFont.headline)
                .foregroundStyle(FreeDayColor.brand)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FreeDaySpacing.touch)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("quick-check-specific-date")
        .accessibilityHint(String(localized: "Checks a chosen start date", comment: "VoiceOver hint for specific date"))
    }

    @ViewBuilder
    private func specificDateControls(formatters: DateFormatters) -> some View {
        Button {
            showSpecificPicker.toggle()
        } label: {
            FreeDayCard(padding: FreeDaySpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        FreeDaySectionHeader(title: String(localized: "Start date", comment: "Specific date check"))
                        Text(formatters.weekdayFull(specificDate))
                            .font(FreeDayFont.display)
                            .foregroundStyle(FreeDayColor.ink)
                        Text(formatters.dayAndMonth(specificDate))
                            .font(FreeDayFont.title)
                            .foregroundStyle(FreeDayColor.ink)
                    }
                    Spacer(minLength: FreeDaySpacing.xs)
                    Image(systemName: "calendar")
                        .foregroundStyle(FreeDayColor.brand)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("quick-check-specific-start")
        .accessibilityLabel(
            String(
                localized: "Start date \(formatters.fullDate(specificDate))",
                comment: "VoiceOver for specific date"
            )
        )

        if showSpecificPicker {
            DatePicker(
                String(localized: "Start date", comment: "Specific date picker"),
                selection: $specificDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(FreeDayColor.brand)
            .accessibilityIdentifier("quick-check-specific-picker")
        }
    }

    @ViewBuilder
    private func results(
        _ result: AvailabilitySearchResult,
        selected: FreeSlot?,
        personality: String?,
        formatters: DateFormatters
    ) -> some View {
        if result.isEmpty {
            FreeDayCard {
                FreeDayEmptyState(
                    title: PersonalityCopy.fullyBooked,
                    message: PersonalityCopy.noSlot(horizonDays: result.horizonDays)
                )
            }
            .accessibilityIdentifier("quick-check-empty")
        } else if let selected {
            VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                mainAnswer(selected, personality: personality, formatters: formatters)

                if !result.others.isEmpty {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        FreeDaySectionHeader(title: String(localized: "Other options", comment: "Additional free slots"))
                        ForEach(Array(result.others.enumerated()), id: \.element.id) { index, slot in
                            otherOption(slot, isSelected: slot.start == selected.start, formatters: formatters)
                                .accessibilityIdentifier("quick-check-other-\(index)")
                        }
                    }
                }
            }
        }
    }

    private func mainAnswer(_ slot: FreeSlot, personality: String?, formatters: DateFormatters) -> some View {
        FreeDayCard(emphasize: .free) {
            VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                AvailabilityHero(
                    kind: .free,
                    title: String(localized: "YES — YOU'RE FREE!", comment: "Quick check free answer")
                )
                StatusBadge(availability: .free)

                endpoint(
                    title: String(localized: "You can start", comment: "Slot start heading"),
                    date: slot.start,
                    formatters: formatters
                )
                Image(systemName: "arrow.down")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(FreeDayColor.muted)
                    .accessibilityHidden(true)
                endpoint(
                    title: String(localized: "You’ll finish", comment: "Slot end heading"),
                    date: slot.end,
                    formatters: formatters
                )

                Text(
                    String(
                        localized: "\(slot.durationWorkingDays) working days",
                        comment: "Slot duration"
                    )
                )
                .font(FreeDayFont.caption)
                .foregroundStyle(FreeDayColor.muted)

                if let personality {
                    PersonalityLine(text: personality, style: .caption)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("quick-check-next-slot")
        .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
    }

    private func otherOption(_ slot: FreeSlot, isSelected: Bool, formatters: DateFormatters) -> some View {
        Button {
            selectedStart = slot.start
            FreeDayHaptics.selection()
        } label: {
            FreeDayCard(padding: FreeDaySpacing.md, emphasize: isSelected ? .free : .none) {
                Text(formatters.compactRange(start: slot.start, end: slot.end))
                    .font(FreeDayFont.headline)
                    .foregroundStyle(FreeDayColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
        .accessibilityHint(String(localized: "Selects this slot for Use These Dates", comment: "Quick check other slot"))
    }

    private func endpoint(title: String, date: Date, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            FreeDaySectionHeader(title: title)
            Text(formatters.weekdayFull(date))
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
            Text(formatters.dayAndMonth(date))
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func actions(selected: FreeSlot?, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: FreeDaySpacing.sm) {
            if selected == nil {
                if horizonDays < QuickCheck.maxHorizon {
                    PrimaryButton(
                        title: String(localized: "Search Further", comment: "Extend quick check horizon"),
                        action: {
                            horizonDays = min(horizonDays + QuickCheck.horizonStep, QuickCheck.maxHorizon)
                            FreeDayHaptics.light()
                        }
                    )
                    .accessibilityIdentifier("quick-check-search-further")
                }
            } else if let selected {
                PrimaryButton(
                    title: String(localized: "Use These Dates", comment: "Prefill add project from quick check"),
                    action: {
                        FreeDayHaptics.selection()
                        onUseDates(selected, duration)
                    }
                )
                .accessibilityIdentifier("quick-check-use-dates")
                SecondaryButton(
                    title: String(localized: "Check Another Date", comment: "Return to quick check controls"),
                    action: {
                        showFromPicker = true
                        withAnimation(Motion.animation(reduceMotion)) {
                            proxy.scrollTo("quick-check-controls", anchor: .top)
                        }
                    }
                )
                .accessibilityIdentifier("quick-check-another-date")
            }
        }
        .padding(.horizontal, FreeDaySpacing.screen)
        .padding(.vertical, FreeDaySpacing.xs)
        .background(FreeDayColor.canvas.opacity(0.96))
        .freeDayContentWidth()
    }

    @ViewBuilder
    private func specificResults(_ result: SpecificDateResult, formatters: DateFormatters) -> some View {
        switch result {
        case .available(_, let slot):
            FreeDayCard(emphasize: .free) {
                VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                    AvailabilityHero(kind: .free, title: PersonalityCopy.yesYoureFree)
                    StatusBadge(availability: .free)
                    endpoint(
                        title: String(localized: "You can start", comment: "Slot start heading"),
                        date: slot.start,
                        formatters: formatters
                    )
                    Image(systemName: "arrow.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(FreeDayColor.muted)
                        .accessibilityHidden(true)
                    endpoint(
                        title: String(localized: "You’ll finish", comment: "Slot end heading"),
                        date: slot.end,
                        formatters: formatters
                    )
                    Text(
                        String(
                            localized: "\(slot.durationWorkingDays) working days",
                            comment: "Slot duration"
                        )
                    )
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)
                    PersonalityLine(text: PersonalityCopy.perfectFit, style: .caption)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("quick-check-specific-available")
            .accessibilityLabel(specificAvailableLabel(slot, formatters: formatters))

        case .unavailable(let start, let conflictName, let next):
            VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                FreeDayCard(emphasize: .booked) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        AvailabilityHero(kind: .booked, title: PersonalityCopy.notAvailable)
                        if let conflictName, !conflictName.isEmpty {
                            Text(PersonalityCopy.conflictsWith(conflictName))
                                .font(FreeDayFont.body)
                                .foregroundStyle(FreeDayColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .accessibilityIdentifier("quick-check-specific-unavailable")

                if let next {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        FreeDaySectionHeader(title: String(localized: "Next available", comment: "Next slot after a conflict"))
                        mainAnswer(next, personality: PersonalityCopy.perfectFit, formatters: formatters)
                    }
                } else {
                    FreeDayCard {
                        FreeDayEmptyState(
                            title: PersonalityCopy.fullyBooked,
                            message: PersonalityCopy.noSlot(horizonDays: horizonDays)
                        )
                    }
                    .accessibilityIdentifier("quick-check-empty")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(specificUnavailableLabel(start: start, conflictName: conflictName, next: next, formatters: formatters))
        }
    }

    @ViewBuilder
    private func specificActions(_ result: SpecificDateResult) -> some View {
        VStack(spacing: FreeDaySpacing.sm) {
            switch result {
            case .available(_, let slot):
                PrimaryButton(
                    title: String(localized: "Use These Dates", comment: "Prefill add project from specific date"),
                    action: {
                        FreeDayHaptics.selection()
                        onUseDates(slot, duration)
                    }
                )
                .accessibilityIdentifier("quick-check-use-dates")
            case .unavailable(_, _, let next):
                if let next {
                    PrimaryButton(
                        title: String(localized: "Use Next Available", comment: "Prefill add project from next slot"),
                        action: {
                            FreeDayHaptics.selection()
                            onUseDates(next, duration)
                        }
                    )
                    .accessibilityIdentifier("quick-check-use-next")
                } else if horizonDays < QuickCheck.maxHorizon {
                    PrimaryButton(
                        title: String(localized: "Search Further", comment: "Extend quick check horizon"),
                        action: {
                            horizonDays = min(horizonDays + QuickCheck.horizonStep, QuickCheck.maxHorizon)
                            FreeDayHaptics.light()
                        }
                    )
                    .accessibilityIdentifier("quick-check-search-further")
                }
            }
            SecondaryButton(
                title: String(localized: "Check From Today", comment: "Return to normal Quick Check"),
                action: {
                    specificDateMode = false
                    showSpecificPicker = false
                    fromDate = Date()
                    selectedStart = nil
                    horizonDays = AvailabilitySearchOptions.defaults.calendarDayHorizon
                    FreeDayHaptics.selection()
                }
            )
            .accessibilityIdentifier("quick-check-from-today")
        }
        .padding(.horizontal, FreeDaySpacing.screen)
        .padding(.vertical, FreeDaySpacing.xs)
        .background(FreeDayColor.canvas.opacity(0.96))
        .freeDayContentWidth()
    }

    private func selectedSlot(in result: AvailabilitySearchResult, calendar: Calendar) -> FreeSlot? {
        if let selectedStart {
            return result.slots.first { calendar.isDate($0.start, inSameDayAs: selectedStart) } ?? result.next
        }
        return result.next
    }

    private func fromLabel(formatters: DateFormatters, calendar: Calendar) -> String {
        if calendar.isDateInToday(fromDate) {
            return String(localized: "Today", comment: "Quick check searches from today")
        }
        return formatters.fullDate(fromDate)
    }

    private func slotAccessibility(_ slot: FreeSlot, formatters: DateFormatters) -> String {
        String(
            localized: "Available from \(formatters.fullDate(slot.start)) through \(formatters.fullDate(slot.end)). \(slot.durationWorkingDays) working days.",
            comment: "VoiceOver for a quick check slot"
        )
    }

    private func specificAvailableLabel(_ slot: FreeSlot, formatters: DateFormatters) -> String {
        String(
            localized: "\(formatters.fullDate(slot.start)). Available for \(slot.durationWorkingDays) working days.",
            comment: "VoiceOver for an available specific date"
        )
    }

    private func specificUnavailableLabel(
        start: Date,
        conflictName: String?,
        next: FreeSlot?,
        formatters: DateFormatters
    ) -> String {
        var message = String(
            localized: "\(formatters.fullDate(start)). Not available.",
            comment: "VoiceOver for an unavailable specific date"
        )
        if let conflictName, !conflictName.isEmpty {
            message += " " + PersonalityCopy.conflictsWith(conflictName)
        }
        if let next {
            message += " " + String(
                localized: "Next available \(formatters.fullDate(next.start)).",
                comment: "VoiceOver next available date"
            )
        }
        return message
    }
}

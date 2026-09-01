import SwiftData
import SwiftUI

struct RescheduleView: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var projects: [Project]

    @Bindable var project: Project
    var onFinished: (String?) -> Void

    @State private var searchEarlier = false
    @State private var searchOverride: Date?
    @State private var pendingSlot: FreeSlot?
    @State private var showDatePicker = false
    @State private var manualDate = Date()
    @State private var staleConflict = false

    var body: some View {
        let engine = environment.scheduling
        let planner = ReschedulePlanner(engine: engine)
        let formatters = DateFormatters(workingCalendar: engine.workingCalendar)
        let snapshot = project.snapshot
        let others = projects.map(\.snapshot)
        let current = planner.currentSlot(for: snapshot)
        let search = planner.alternatives(
            for: snapshot,
            among: others,
            searchEarlier: searchEarlier,
            from: searchOverride
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                    if pendingSlot == nil {
                        header(snapshot: snapshot, current: current, formatters: formatters)

                        Toggle(
                            String(localized: "Search earlier dates", comment: "Look before the original start"),
                            isOn: $searchEarlier
                        )
                        .font(FreeDayFont.headline)
                        .foregroundStyle(FreeDayColor.ink)
                        .tint(FreeDayColor.brand)
                        .accessibilityIdentifier("reschedule-search-earlier")
                    }

                    if let pendingSlot {
                        confirmationContent(
                            slot: pendingSlot,
                            current: current,
                            snapshot: snapshot,
                            formatters: formatters
                        )
                    } else if search.isEmpty {
                        emptyCard(horizonDays: search.horizonDays)
                    } else if let next = search.next {
                        earliestCard(next, formatters: formatters)
                        if !search.others.isEmpty {
                            otherOptions(search.others, formatters: formatters)
                        }
                    }

                    if pendingSlot == nil {
                        SecondaryButton(
                            title: String(localized: "Choose a Date", comment: "Manual reschedule date"),
                            action: {
                                manualDate = snapshot.startDate ?? .now
                                showDatePicker = true
                            }
                        )
                        .accessibilityIdentifier("reschedule-choose-date")
                    }
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.lg)
                .animation(Motion.animation(reduceMotion), value: search.slots.map(\.start))
                .animation(Motion.animation(reduceMotion), value: searchEarlier)
                .animation(Motion.animation(reduceMotion), value: pendingSlot?.start)
                .freeDayContentWidth()
            }
            .background(FreeDayColor.canvas.ignoresSafeArea())
            .navigationTitle(String(localized: "Reschedule", comment: "Reschedule screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel reschedule")) {
                        onFinished(nil)
                        dismiss()
                    }
                    .accessibilityIdentifier("reschedule-cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let pendingSlot {
                    VStack(spacing: FreeDaySpacing.sm) {
                        PrimaryButton(
                            title: String(localized: "Confirm New Dates", comment: "Save reschedule"),
                            action: { confirm(slot: pendingSlot) }
                        )
                        .accessibilityIdentifier("reschedule-confirm")
                        .accessibilityLabel(
                            String(
                                localized: "Confirm moving \(snapshot.customerName) to \(formatters.fullDate(pendingSlot.start)) through \(formatters.fullDate(pendingSlot.end)).",
                                comment: "VoiceOver confirm reschedule"
                            )
                        )
                    }
                    .padding(.horizontal, FreeDaySpacing.screen)
                    .padding(.vertical, FreeDaySpacing.xs)
                    .background(FreeDayColor.canvas.opacity(0.96))
                    .freeDayContentWidth()
                }
            }
            .onChange(of: searchEarlier) { _, _ in
                searchOverride = nil
            }
            .sheet(isPresented: $showDatePicker) {
                manualDateSheet(planner: planner, snapshot: snapshot, others: others, formatters: formatters)
            }
            .alert(
                PersonalityCopy.datesNoLongerAvailable,
                isPresented: $staleConflict
            ) {
                Button(String(localized: "OK", comment: "Dismiss stale conflict"), role: .cancel) {}
            }
        }
    }

    private func header(snapshot: ProjectSnapshot, current: FreeSlot?, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
            Text(String(localized: "Reschedule job", comment: "Reschedule heading"))
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
            Text(snapshot.customerName)
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)

            FreeDayCard(emphasize: .current) {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(title: String(localized: "Current booking", comment: "Current booking heading"))
                    if let current {
                        Text(formatters.fullRange(start: current.start, end: current.end))
                            .font(FreeDayFont.headline)
                            .foregroundStyle(FreeDayColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(FreeDayDurationCopy.workingDays(snapshot.durationInWorkingDays))
                    .font(FreeDayFont.body)
                    .foregroundStyle(FreeDayColor.muted)
                    if snapshot.bufferInWorkingDays > 0 {
                        Text(
                            snapshot.bufferInWorkingDays == 1
                                ? String(localized: "1 day after job", comment: "Reschedule buffer note")
                                : String(
                                    localized: "\(snapshot.bufferInWorkingDays) days after job",
                                    comment: "Reschedule buffer note"
                                )
                        )
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.buffer)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func emptyCard(horizonDays: Int) -> some View {
        FreeDayCard {
            FreeDayEmptyState(
                title: PersonalityCopy.fullyBooked,
                message: PersonalityCopy.noSlot(horizonDays: horizonDays)
            )
        }
        .accessibilityIdentifier("reschedule-empty")
    }

    private func earliestCard(_ slot: FreeSlot, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            FreeDaySectionHeader(title: String(localized: "Earliest available", comment: "First reschedule slot"))

            Button {
                FreeDayHaptics.selection()
                pendingSlot = slot
            } label: {
                FreeDayCard(emphasize: .proposed) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
                        HStack(spacing: FreeDaySpacing.xs) {
                            StatusBadge(availability: .free)
                            Text(PersonalityCopy.perfectFit)
                                .font(FreeDayFont.headline)
                                .foregroundStyle(FreeDayColor.ink)
                        }
                        slotEndpoints(slot, formatters: formatters)
                        Text(FreeDayDurationCopy.workingDays(slot.durationWorkingDays))
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.muted)
                    }
                }
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier("reschedule-earliest-slot")
            .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
            .accessibilityHint(String(localized: "Shows a confirmation before moving this job", comment: "Choose reschedule slot"))
        }
    }

    private func otherOptions(_ slots: [FreeSlot], formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            FreeDaySectionHeader(title: String(localized: "Other options", comment: "Additional reschedule slots"))

            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                Button {
                    FreeDayHaptics.selection()
                    pendingSlot = slot
                } label: {
                    FreeDayCard(padding: FreeDaySpacing.md) {
                        VStack(alignment: .leading, spacing: 4) {
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
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("reschedule-other-\(index)")
                .accessibilityLabel(slotAccessibility(slot, formatters: formatters))
                .accessibilityHint(String(localized: "Shows a confirmation before moving this job", comment: "Choose reschedule slot"))
            }
        }
    }

    private func slotEndpoints(_ slot: FreeSlot, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
            endpoint(
                title: String(localized: "You can start", comment: "Slot start heading"),
                date: slot.start,
                formatters: formatters
            )
            endpoint(
                title: String(localized: "You’ll finish", comment: "Slot end heading"),
                date: slot.end,
                formatters: formatters
            )
        }
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

    private func confirmationContent(
        slot: FreeSlot,
        current: FreeSlot?,
        snapshot: ProjectSnapshot,
        formatters: DateFormatters
    ) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
            Text(String(localized: "Move job?", comment: "Reschedule confirmation title"))
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
            Text(snapshot.customerName)
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)

            if let current {
                FreeDayCard(emphasize: .current) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                        FreeDaySectionHeader(title: String(localized: "From", comment: "Current dates in confirmation"))
                        Text(formatters.fullRange(start: current.start, end: current.end))
                            .font(FreeDayFont.title)
                            .foregroundStyle(FreeDayColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            FreeDayCard(emphasize: .proposed) {
                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                    FreeDaySectionHeader(title: String(localized: "To", comment: "New dates in confirmation"))
                    Text(formatters.fullRange(start: slot.start, end: slot.end))
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(FreeDayDurationCopy.workingDays(slot.durationWorkingDays))
                    .font(FreeDayFont.caption)
                    .foregroundStyle(FreeDayColor.muted)
                }
            }

            SecondaryButton(
                title: String(localized: "Cancel", comment: "Cancel slot confirmation"),
                action: { pendingSlot = nil }
            )
            .accessibilityIdentifier("reschedule-confirmation-cancel")
        }
    }

    private func manualDateSheet(
        planner: ReschedulePlanner,
        snapshot: ProjectSnapshot,
        others: [ProjectSnapshot],
        formatters: DateFormatters
    ) -> some View {
        let preview = planner.preview(start: manualDate, duration: snapshot.durationInWorkingDays)
        let decision = planner.evaluate(start: manualDate, project: snapshot, among: others)

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
                    Text(String(localized: "Choose a date", comment: "Manual date title"))
                        .font(FreeDayFont.title)
                        .foregroundStyle(FreeDayColor.ink)

                    DatePicker(
                        String(localized: "New start date", comment: "Manual reschedule picker"),
                        selection: $manualDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(FreeDayColor.brand)
                    .accessibilityIdentifier("reschedule-manual-picker")

                    if let preview {
                        switch decision {
                        case .allowed:
                            FreeDayCard(emphasize: .proposed) {
                                VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                                    FreeDaySectionHeader(title: String(localized: "New booking", comment: "Manual date preview"))
                                    Text(formatters.fullRange(start: preview.start, end: preview.end))
                                        .font(FreeDayFont.title)
                                        .foregroundStyle(FreeDayColor.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(FreeDayDurationCopy.workingDays(preview.durationWorkingDays))
                                    .font(FreeDayFont.caption)
                                    .foregroundStyle(FreeDayColor.muted)
                                }
                            }
                        case .blocked:
                            FreeDayCard(emphasize: .booked) {
                                Text(PersonalityCopy.datesConflict)
                                    .font(FreeDayFont.body)
                                    .foregroundStyle(FreeDayColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.lg)
                .freeDayContentWidth()
            }
            .background(FreeDayColor.canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel manual date")) {
                        showDatePicker = false
                    }
                    .accessibilityIdentifier("reschedule-manual-cancel")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: FreeDaySpacing.sm) {
                    if let preview, case .allowed = decision {
                        PrimaryButton(
                            title: String(localized: "Confirm New Dates", comment: "Save manual reschedule"),
                            action: {
                                let chosen = preview
                                showDatePicker = false
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(320))
                                    pendingSlot = chosen
                                }
                            }
                        )
                        .accessibilityIdentifier("reschedule-manual-confirm")
                    } else if case .blocked = decision {
                        PrimaryButton(
                            title: String(localized: "Find Next Available", comment: "Search after manual conflict"),
                            action: {
                                searchOverride = manualDate
                                showDatePicker = false
                            }
                        )
                        .accessibilityIdentifier("reschedule-find-next")
                    }
                }
                .padding(.horizontal, FreeDaySpacing.screen)
                .padding(.vertical, FreeDaySpacing.xs)
                .background(FreeDayColor.canvas.opacity(0.96))
                .freeDayContentWidth()
            }
        }
        .presentationDetents([.large])
    }

    private func slotAccessibility(_ slot: FreeSlot, formatters: DateFormatters) -> String {
        "\(formatters.fullDate(slot.start)) to \(formatters.fullDate(slot.end)), \(FreeDayDurationCopy.workingDays(slot.durationWorkingDays))"
    }

    private func confirm(slot: FreeSlot) {
        let planner = ReschedulePlanner(engine: environment.scheduling)
        let snapshot = project.snapshot
        let others = projects.map(\.snapshot)
        switch planner.evaluate(slot: slot, project: snapshot, among: others) {
        case .allowed:
            project.startDate = slot.start
            try? modelContext.save()
            pendingSlot = nil
            FreeDayHaptics.success()
            onFinished(PersonalityCopy.newDatesLockedIn)
            dismiss()
        case .blocked:
            pendingSlot = nil
            staleConflict = true
            FreeDayHaptics.warning()
        }
    }
}

import SwiftData
import SwiftUI

struct ComingView: View {
    @Environment(\.appEnvironment) private var environment
    @Query private var projects: [Project]

    var onFindFreeDays: () -> Void
    var onUseFreeDay: (Date) -> Void

    @State private var pendingFreeDay: ComingDay?

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: engine.workingCalendar)
        let snapshot = ComingCapacityBuilder(engine: engine).make(
            projects: projects.map(\.snapshot),
            now: .now
        )

        ScrollView {
            VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                summary(snapshot)
                busyMeter(snapshot)
                schedule(snapshot, formatters: formatters)
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.vertical, FreeDaySpacing.lg)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "What’s Coming?", comment: "Capacity screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: String(localized: "Find My Next Free Days", comment: "Open Find Free Days from capacity"),
                systemImage: "magnifyingglass",
                action: onFindFreeDays
            )
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.vertical, FreeDaySpacing.xs)
            .background(FreeDayColor.canvas.opacity(0.96))
            .accessibilityIdentifier("coming-find-free-days")
            .freeDayContentWidth()
        }
        .confirmationDialog(
            pendingFreeDay.map { formatters.fullDate($0.date) } ?? "",
            isPresented: Binding(
                get: { pendingFreeDay != nil },
                set: { if !$0 { pendingFreeDay = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Use this day", comment: "Free day capacity action")) {
                if let day = pendingFreeDay {
                    onUseFreeDay(day.date)
                }
                pendingFreeDay = nil
            }
            Button(String(localized: "Cancel", comment: "Cancel free day action"), role: .cancel) {
                pendingFreeDay = nil
            }
        } message: {
            Text(String(localized: "Add a project starting on this day.", comment: "Free day capacity explanation"))
        }
    }

    private func summary(_ snapshot: ComingCapacity) -> some View {
        HStack(alignment: .top, spacing: FreeDaySpacing.sm) {
            metric(
                value: snapshot.freeWorkingDays,
                title: snapshot.freeWorkingDays == 1
                    ? String(localized: "Free day", comment: "Capacity metric")
                    : String(localized: "Free days", comment: "Capacity metric"),
                identifier: "coming-metric-free",
                spoken: String(
                    localized: "\(snapshot.freeWorkingDays) free days",
                    comment: "VoiceOver free-day count"
                )
            )
            metric(
                value: snapshot.bookedJobs,
                title: snapshot.bookedJobs == 1
                    ? String(localized: "Booked job", comment: "Capacity metric")
                    : String(localized: "Booked jobs", comment: "Capacity metric"),
                identifier: "coming-metric-booked",
                spoken: String(
                    localized: "\(snapshot.bookedJobs) booked jobs",
                    comment: "VoiceOver booked-job count"
                )
            )
            metric(
                value: snapshot.bufferDays,
                title: snapshot.bufferDays == 1
                    ? String(localized: "Buffer day", comment: "Capacity metric")
                    : String(localized: "Buffer days", comment: "Capacity metric"),
                identifier: "coming-metric-buffer",
                spoken: String(
                    localized: "\(snapshot.bufferDays) buffer days",
                    comment: "VoiceOver buffer-day count"
                )
            )
        }
        .accessibilityIdentifier("coming-summary")
    }

    private func metric(value: Int, title: String, identifier: String, spoken: String) -> some View {
        FreeDayCard(padding: FreeDaySpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(FreeDayFont.display)
                    .foregroundStyle(FreeDayColor.ink)
                    .monospacedDigit()
                Text(title)
                    .font(FreeDayFont.label)
                    .foregroundStyle(FreeDayColor.muted)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)
        .accessibilityIdentifier(identifier)
    }

    private func schedule(_ snapshot: ComingCapacity, formatters: DateFormatters) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.lg) {
            FreeDaySectionHeader(title: String(localized: "Next 14 days", comment: "Capacity day list"))

            ForEach(snapshot.sections) { section in
                VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                    FreeDaySectionHeader(title: sectionTitle(section, formatters: formatters))
                    ForEach(section.days) { day in
                        dayRow(day, formatters: formatters)
                    }
                }
            }
        }
        .accessibilityIdentifier("coming-schedule")
    }

    @ViewBuilder
    private func dayRow(_ day: ComingDay, formatters: DateFormatters) -> some View {
        Button {
            guard day.canUseDay else { return }
            pendingFreeDay = day
        } label: {
            ComingDayRow(day: day, formatters: formatters)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier("coming-day-\(day.isoDate)")
        .accessibilityLabel(day.spokenLabel(fullDate: formatters.fullDate(day.date)))
        .accessibilityHint(
            day.canUseDay
                ? String(localized: "Use this free day", comment: "Capacity free day")
                : ""
        )
        .accessibilityAddTraits(.isButton)
    }

    private func busyMeter(_ snapshot: ComingCapacity) -> some View {
        FreeDayCard {
            VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                FreeDaySectionHeader(title: String(localized: "How busy?", comment: "Busy meter heading"))
                Text(snapshot.busyLevel.title)
                    .font(FreeDayFont.display)
                    .foregroundStyle(FreeDayColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                occupancyBar(snapshot)
                PersonalityLine(text: snapshot.personality, style: .caption)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(snapshot.spokenBusyMeter)
        .accessibilityIdentifier("coming-busy-meter")
    }

    private func occupancyBar(_ snapshot: ComingCapacity) -> some View {
        GeometryReader { proxy in
            let fraction = snapshot.workingDayCount == 0
                ? 0
                : CGFloat(snapshot.occupiedWorkingDays) / CGFloat(snapshot.workingDayCount)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FreeDayColor.hairline.opacity(0.45))
                Capsule()
                    .fill(meterColor(snapshot.busyLevel))
                    .frame(width: max(proxy.size.width * fraction, snapshot.occupiedWorkingDays == 0 ? 0 : 8))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    private func meterColor(_ level: BusyLevel) -> Color {
        switch level {
        case .light: FreeDayColor.free
        case .balanced: FreeDayColor.brand
        case .busy: FreeDayColor.buffer
        case .packed: FreeDayColor.booked
        }
    }

    private func sectionTitle(_ section: ComingSection, formatters: DateFormatters) -> String {
        switch section.kind {
        case .thisWeek:
            String(localized: "This week", comment: "Capacity section")
        case .nextWeek:
            String(localized: "Next week", comment: "Capacity section")
        case .later:
            formatters.weekRange(
                monday: section.days.first?.date ?? section.weekStart,
                friday: section.days.last?.date ?? section.weekStart
            )
        }
    }
}

private struct ComingDayRow: View {
    let day: ComingDay
    let formatters: DateFormatters

    var body: some View {
        HStack(alignment: .center, spacing: FreeDaySpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                if day.isToday {
                    Text(String(localized: "Today", comment: "Today marker on a capacity row"))
                        .font(FreeDayFont.label)
                        .foregroundStyle(FreeDayColor.brand)
                        .textCase(.uppercase)
                        .tracking(1.2)
                }
                Text(formatters.compactDate(day.date).uppercased())
                    .font(day.isWorkingDay ? FreeDayFont.headline : FreeDayFont.caption)
                    .foregroundStyle(day.isWorkingDay ? FreeDayColor.ink : FreeDayColor.muted)
            }
            Spacer(minLength: FreeDaySpacing.xs)
            VStack(alignment: .trailing, spacing: 2) {
                CalendarStatusBadge(kind: day.kind)
                if let name = day.displayName {
                    Text(name)
                        .font(FreeDayFont.caption)
                        .foregroundStyle(FreeDayColor.ink)
                        .lineLimit(1)
                        .accessibilityElement()
                        .accessibilityLabel(name)
                }
            }
        }
        .padding(day.isWorkingDay ? FreeDaySpacing.md : FreeDaySpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FreeDayColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FreeDayRadius.card, style: .continuous)
                .stroke(border, lineWidth: day.isToday ? 2 : 1)
        )
        .opacity(day.isWorkingDay ? 1 : 0.58)
    }

    private var border: Color {
        if day.isToday { return FreeDayColor.brand }
        switch day.kind {
        case .free: return FreeDayColor.free.opacity(0.45)
        case .booked: return FreeDayColor.booked.opacity(0.5)
        case .buffer: return FreeDayColor.buffer.opacity(0.55)
        default: return FreeDayColor.hairline.opacity(0.55)
        }
    }
}

import SwiftData
import SwiftUI

struct CalendarScreen: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var projects: [Project]

    var onUseFreeDay: (Date) -> Void

    @State private var visibleDate = Date()
    @State private var mode: Mode = .week
    @State private var pendingFreeDay: CalendarDayModel?
    @State private var selectedProject: IdentifiedProject?

    private struct IdentifiedProject: Identifiable, Hashable {
        let id: UUID
    }

    private enum Mode: String, CaseIterable, Identifiable {
        case week
        case month
        var id: String { rawValue }

        var title: String {
            switch self {
            case .week: String(localized: "Week", comment: "Calendar mode")
            case .month: String(localized: "Month", comment: "Calendar mode")
            }
        }
    }

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: engine.workingCalendar)
        let presentation = CalendarPresentation(engine: engine)
        let snapshots = projects.map(\.snapshot)
        let now = Date()
        let week = presentation.week(containing: visibleDate, projects: snapshots, now: now)
        let month = presentation.month(containing: visibleDate, projects: snapshots, now: now)

        ScrollView {
            VStack(alignment: .leading, spacing: FreeDaySpacing.md) {
                Picker(String(localized: "Calendar view", comment: "Week or month"), selection: $mode) {
                    ForEach(Mode.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .tint(FreeDayColor.brand)
                .accessibilityIdentifier("calendar-mode")

                if mode == .week, let personality = week.personality {
                    PersonalityLine(text: personality, style: .caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("calendar-week-personality")
                }

                titleRow(mode: mode, week: week, month: month, formatters: formatters)
                navigationRow(
                    presentation: presentation,
                    isCurrent: mode == .week
                        ? presentation.isCurrentWeek(visibleDate, now: now)
                        : presentation.isCurrentMonth(visibleDate, now: now)
                )

                Group {
                    if mode == .week {
                        WeekView(week: week, formatters: formatters, onSelect: handleSelection)
                    } else {
                        MonthView(month: month, formatters: formatters, onSelect: handleSelection)
                    }
                }
                .freeDayContentWidth(FreeDaySpacing.iPadCalendar)
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.xs)
            .padding(.bottom, FreeDaySpacing.xl)
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "Calendar", comment: "Calendar screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedProject) { route in
            if let project = projects.first(where: { $0.id == route.id }) {
                ProjectDetailView(project: project)
            }
        }
        .confirmationDialog(
            pendingFreeDay.map { formatters.fullDate($0.date) } ?? "",
            isPresented: Binding(
                get: { pendingFreeDay != nil },
                set: { if !$0 { pendingFreeDay = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "Use this day", comment: "Free day calendar action")) {
                if let day = pendingFreeDay {
                    onUseFreeDay(day.date)
                }
                pendingFreeDay = nil
            }
            Button(String(localized: "Cancel", comment: "Cancel free day action"), role: .cancel) {
                pendingFreeDay = nil
            }
        } message: {
            Text(String(localized: "Add a project starting on this day.", comment: "Free day calendar explanation"))
        }
        .onAppear {
            visibleDate = engine.workingCalendar.startOfDay(.now)
        }
        .animation(Motion.animation(reduceMotion), value: mode)
        .animation(Motion.animation(reduceMotion), value: week.start)
    }

    private func titleRow(
        mode: Mode,
        week: CalendarWeekModel,
        month: CalendarMonthModel,
        formatters: DateFormatters
    ) -> some View {
        Text(title(mode: mode, week: week, month: month, formatters: formatters))
            .font(FreeDayFont.title)
            .foregroundStyle(FreeDayColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("calendar-title")
    }

    private func title(
        mode: Mode,
        week: CalendarWeekModel,
        month: CalendarMonthModel,
        formatters: DateFormatters
    ) -> String {
        if mode == .month {
            return formatters.monthTitle(month.monthStart)
        }
        guard let first = week.workingDays.first?.date, let last = week.workingDays.last?.date else {
            return formatters.mediumDate(week.start)
        }
        return formatters.weekRange(monday: first, friday: last)
    }

    private func navigationRow(presentation: CalendarPresentation, isCurrent: Bool) -> some View {
        HStack(spacing: FreeDaySpacing.xs) {
            navButton(
                title: String(localized: "Previous", comment: "Calendar previous period"),
                accessibilityLabel: mode == .week
                    ? String(localized: "Previous Week", comment: "Calendar week navigation")
                    : String(localized: "Previous Month", comment: "Calendar month navigation"),
                identifier: "calendar-previous"
            ) {
                shift(presentation, by: -1)
            }

            Spacer(minLength: 4)

            navButton(
                title: mode == .week
                    ? String(localized: "Today", comment: "Return to current week")
                    : String(localized: "Current", comment: "Return to current month"),
                accessibilityLabel: mode == .week
                    ? String(localized: "Today", comment: "Return to current week")
                    : String(localized: "Current Month", comment: "Return to current month"),
                identifier: "calendar-today",
                emphasized: !isCurrent
            ) {
                visibleDate = environment.scheduling.workingCalendar.startOfDay(.now)
            }
            .disabled(isCurrent)
            .opacity(isCurrent ? 0.45 : 1)

            Spacer(minLength: 4)

            navButton(
                title: String(localized: "Next", comment: "Calendar next period"),
                accessibilityLabel: mode == .week
                    ? String(localized: "Next Week", comment: "Calendar week navigation")
                    : String(localized: "Next Month", comment: "Calendar month navigation"),
                identifier: "calendar-next"
            ) {
                shift(presentation, by: 1)
            }
        }
        .font(FreeDayFont.caption.weight(.semibold))
    }

    private func navButton(
        title: String,
        accessibilityLabel: String,
        identifier: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(emphasized ? FreeDayColor.brand : FreeDayColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, FreeDaySpacing.sm)
                .frame(minHeight: FreeDaySpacing.touch)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }

    private func shift(_ presentation: CalendarPresentation, by value: Int) {
        if mode == .week {
            visibleDate = presentation.addingWeeks(value, to: visibleDate)
        } else {
            visibleDate = presentation.addingMonths(value, to: visibleDate)
        }
    }

    private func handleSelection(_ day: CalendarDayModel) {
        if let project = day.projectToOpen {
            selectedProject = IdentifiedProject(id: project.id)
            return
        }
        if day.canUseDay {
            pendingFreeDay = day
        }
    }
}

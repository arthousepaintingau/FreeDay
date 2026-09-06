import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.appEnvironment) private var environment
    @Query(sort: \Project.startDate) private var projects: [Project]

    var onFindFreeDays: () -> Void
    var onQuickCheck: () -> Void
    var onAddProject: () -> Void
    var onUseFreeDay: (Date) -> Void

    @State private var showComing = false
    @State private var showSettings = false

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)
        let snapshots = projects.map(\.snapshot)
        let summary = HomeSummaryBuilder(engine: engine).make(projects: snapshots, now: .now)

        ScrollView {
            VStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                header(summary: summary)

                FreeDayCard(emphasize: todayEmphasis(summary.todayAvailability)) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        FreeDaySectionHeader(title: String(localized: "Free today?", comment: "Home status heading"))
                        StatusBadge(availability: summary.todayAvailability)
                        todayAnswer(summary.todayAvailability)
                    }
                    .accessibilityElement(children: .combine)
                }

                FreeDayCard(emphasize: summary.nextAvailable == nil ? .booked : .free) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                        FreeDaySectionHeader(title: String(localized: "Next available", comment: "Home next free day heading"))
                        if let next = summary.nextAvailable {
                            nextAvailable(next, formatters: formatters, calendar: engine.workingCalendar.calendar)
                        } else {
                            Text(String(localized: "No free days in the next year", comment: "Home when fully booked"))
                                .font(FreeDayFont.title)
                                .foregroundStyle(FreeDayColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                comingTeaser(
                    ComingCapacityBuilder(engine: engine).make(projects: snapshots, now: .now)
                )

                upcomingSection(summary.upcoming, engine: engine, formatters: formatters)
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.xs)
            .padding(.bottom, FreeDaySpacing.xl)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationDestination(for: UUID.self) { id in
            if let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: project)
            }
        }
        .navigationDestination(isPresented: $showComing) {
            ComingView(onFindFreeDays: onFindFreeDays, onUseFreeDay: onUseFreeDay)
        }
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("FreeWorkDates")
                    .font(FreeDayFont.headline)
                    .foregroundStyle(FreeDayColor.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(String(localized: "Settings", comment: "Open settings"))
                .accessibilityIdentifier("home-settings")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: FreeDaySpacing.sm) {
                PrimaryButton(
                    title: String(localized: "Find Free Days", comment: "Primary home action"),
                    systemImage: "magnifyingglass",
                    action: onFindFreeDays
                )
                .accessibilityIdentifier("home-find-free-days")
                HStack(spacing: FreeDaySpacing.sm) {
                    SecondaryButton(
                        title: String(localized: "Quick Check", comment: "Secondary home availability check"),
                        systemImage: "clock",
                        action: onQuickCheck
                    )
                    .accessibilityIdentifier("home-quick-check")
                    SecondaryButton(
                        title: String(localized: "Add Project", comment: "Secondary home action"),
                        systemImage: "plus",
                        action: onAddProject
                    )
                }
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.top, FreeDaySpacing.xs)
            .padding(.bottom, FreeDaySpacing.xs)
            .background(FreeDayColor.canvas.opacity(0.96))
            .freeDayContentWidth()
        }
    }

    @ViewBuilder
    private func header(summary: HomeSummary) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
            Text(String(localized: "Know when you can say YES.", comment: "Tagline"))
                .font(FreeDayFont.caption)
                .foregroundStyle(FreeDayColor.muted)
            if let personality = summary.personality {
                PersonalityLine(text: personality)
            }
        }
        .padding(.top, FreeDaySpacing.xs)
    }

    private func comingTeaser(_ snapshot: ComingCapacity) -> some View {
        Button {
            showComing = true
        } label: {
            FreeDayCard {
                HStack(alignment: .center, spacing: FreeDaySpacing.md) {
                    VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
                        FreeDaySectionHeader(title: String(localized: "What’s Coming", comment: "Home capacity teaser"))
                        Text(String(localized: "Next 14 days", comment: "Home capacity window"))
                            .font(FreeDayFont.caption)
                            .foregroundStyle(FreeDayColor.muted)
                        Text(snapshot.homeSummaryLine)
                            .font(FreeDayFont.headline)
                            .foregroundStyle(FreeDayColor.ink)
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
        .accessibilityIdentifier("home-whats-coming")
        .accessibilityLabel(
            String(
                localized: "What’s Coming. Next 14 days. \(snapshot.homeSummaryLine).",
                comment: "VoiceOver for Home capacity teaser"
            )
        )
    }

    @ViewBuilder
    private func nextAvailable(_ date: Date, formatters: DateFormatters, calendar: Calendar) -> some View {
        if calendar.isDateInToday(date) {
            Text(String(localized: "Today", comment: "Next available is today"))
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                if calendar.isDateInTomorrow(date) {
                    Text(String(localized: "Tomorrow", comment: "Next available is tomorrow"))
                        .font(FreeDayFont.label)
                        .foregroundStyle(FreeDayColor.muted)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
                Text(formatters.weekdayFull(date))
                    .font(FreeDayFont.display)
                    .foregroundStyle(FreeDayColor.ink)
                Text(formatters.dayAndMonth(date))
                    .font(FreeDayFont.title)
                    .foregroundStyle(FreeDayColor.ink)
            }
        }
    }

    @ViewBuilder
    private func upcomingSection(
        _ upcoming: [ProjectSnapshot],
        engine: SchedulingEngine,
        formatters: DateFormatters
    ) -> some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
            FreeDaySectionHeader(title: String(localized: "Upcoming jobs", comment: "Home list heading"))

            if upcoming.isEmpty {
                FreeDayCard {
                    FreeDayEmptyState(
                        title: String(localized: "Nothing coming up.", comment: "Empty upcoming jobs title"),
                        message: String(localized: "Enjoy the space.", comment: "Empty upcoming jobs message"),
                        mascot: .free
                    )
                }
            } else {
                ForEach(upcoming) { project in
                    let dates = project.startDate.map {
                        engine.workingDates(start: $0, duration: project.durationInWorkingDays)
                    } ?? []
                    NavigationLink(value: project.id) {
                        ProjectCard(project: project, workingDates: dates, formatters: formatters)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    @ViewBuilder
    private func todayAnswer(_ availability: DayAvailability) -> some View {
        switch availability {
        case .free:
            AvailabilityHero(
                kind: .free,
                title: String(localized: "YES — YOU'RE FREE!", comment: "Home today free")
            )
        case .booked:
            AvailabilityHero(
                kind: .booked,
                title: String(localized: "NO — BOOKED", comment: "Home today booked")
            )
        case .tentative, .nonWorking:
            Text(todayCopy(availability))
                .font(FreeDayFont.display)
                .foregroundStyle(FreeDayColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func todayCopy(_ availability: DayAvailability) -> String {
        switch availability {
        case .free:
            String(localized: "Yes — you’re free", comment: "Home today free")
        case .booked:
            String(localized: "Booked today", comment: "Home today booked")
        case .tentative:
            String(localized: "Quoted — still open", comment: "Home today tentative")
        case .nonWorking:
            String(localized: "You’re off today", comment: "Home today weekend")
        }
    }

    private func todayEmphasis(_ availability: DayAvailability) -> FreeDayCardEmphasis {
        switch availability {
        case .free: .free
        case .booked: .booked
        case .tentative: .none
        case .nonWorking: .current
        }
    }
}

import SwiftData
import SwiftUI

struct ProjectsListView: View {
    @Environment(\.appEnvironment) private var environment
    @Query(sort: \Project.createdDate, order: .reverse) private var projects: [Project]

    @State private var showAdd = false

    var body: some View {
        let engine = environment.scheduling
        let formatters = DateFormatters(workingCalendar: environment.workingCalendar)
        let booked = sorted(projects.filter { $0.status == .booked })
        let quoted = sorted(projects.filter { $0.status == .quoted })
        let completed = sorted(projects.filter { $0.status == .completed })

        ScrollView {
            LazyVStack(alignment: .leading, spacing: FreeDaySpacing.xl) {
                if projects.isEmpty {
                    FreeDayEmptyState(
                        title: String(localized: "No projects yet.", comment: "Empty project list title"),
                        message: String(
                            localized: "Add your first job and we’ll keep track of your free days.",
                            comment: "Empty project list message"
                        )
                    )
                    .padding(.top, FreeDaySpacing.md)
                } else {
                    section(
                        String(localized: "Booked", comment: "Project list group"),
                        projects: booked,
                        engine: engine,
                        formatters: formatters
                    )
                    section(
                        String(localized: "Quoted", comment: "Project list group"),
                        projects: quoted,
                        engine: engine,
                        formatters: formatters
                    )
                    section(
                        String(localized: "Completed", comment: "Project list group"),
                        projects: completed,
                        engine: engine,
                        formatters: formatters
                    )
                }
            }
            .padding(.horizontal, FreeDaySpacing.screen)
            .padding(.vertical, FreeDaySpacing.lg)
            .freeDayContentWidth()
        }
        .background(FreeDayColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "Jobs", comment: "Projects screen title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Add Project", comment: "Jobs toolbar add"))
            }
        }
        .sheet(isPresented: $showAdd) {
            ProjectEditorView(mode: .create(ProjectPrefill())) { _ in }
        }
        .navigationDestination(for: PersistentIdentifier.self) { id in
            if let project = projects.first(where: { $0.persistentModelID == id }) {
                ProjectDetailView(project: project)
            }
        }
    }

    @ViewBuilder
    private func section(
        _ title: String,
        projects: [Project],
        engine: SchedulingEngine,
        formatters: DateFormatters
    ) -> some View {
        if !projects.isEmpty {
            VStack(alignment: .leading, spacing: FreeDaySpacing.sm) {
                FreeDaySectionHeader(title: title)

                ForEach(projects) { project in
                    let snapshot = project.snapshot
                    let dates = snapshot.startDate.map {
                        engine.workingDates(start: $0, duration: snapshot.durationInWorkingDays)
                    } ?? []
                    NavigationLink(value: project.persistentModelID) {
                        ProjectCard(project: snapshot, workingDates: dates, formatters: formatters)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    private func sorted(_ projects: [Project]) -> [Project] {
        projects.sorted { lhs, rhs in
            let left = lhs.startDate ?? .distantFuture
            let right = rhs.startDate ?? .distantFuture
            if left != right { return left < right }
            return lhs.createdDate > rhs.createdDate
        }
    }
}

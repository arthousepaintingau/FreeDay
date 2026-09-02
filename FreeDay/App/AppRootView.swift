import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(WorkWeekStore.self) private var workWeek
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var tab: AppTab = .home
    @State private var sheet: AppSheet?
    @State private var toast: String?

    var body: some View {
        TabView(selection: $tab) {
            Tab(String(localized: "Home", comment: "Tab title"), systemImage: "sun.max.fill", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        onFindFreeDays: { sheet = .findFreeDays },
                        onQuickCheck: { sheet = .quickCheck },
                        onAddProject: { sheet = .addProject(ProjectPrefill()) },
                        onUseFreeDay: { date in
                            sheet = .addProject(
                                ProjectPrefill(
                                    startDate: date,
                                    durationInWorkingDays: 1,
                                    status: .booked
                                )
                            )
                        }
                    )
                }
            }

            Tab(String(localized: "Calendar", comment: "Tab title"), systemImage: "calendar", value: AppTab.week) {
                NavigationStack {
                    CalendarScreen { date in
                        sheet = .addProject(
                            ProjectPrefill(
                                startDate: date,
                                durationInWorkingDays: 1,
                                status: .booked
                            )
                        )
                    }
                }
            }

            Tab(String(localized: "Jobs", comment: "Tab title"), systemImage: "rectangle.stack.fill", value: AppTab.jobs) {
                NavigationStack {
                    ProjectsListView()
                }
            }
        }
        .tint(FreeDayColor.brand)
        .environment(\.appEnvironment, workWeek.appEnvironment)
        .sheet(item: $sheet, content: sheetContent)
        .overlay(alignment: .top) {
            if let toast {
                ToastBanner(message: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Motion.animation(reduceMotion), value: toast)
    }

    private func presentAddProject(_ prefill: ProjectPrefill) {
        sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            sheet = .addProject(prefill)
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .findFreeDays:
            FindFreeDaysView { slot, duration in
                presentAddProject(
                    ProjectPrefill(
                        startDate: slot.start,
                        durationInWorkingDays: duration,
                        status: .booked,
                        showFitMessage: true
                    )
                )
            }
        case .quickCheck:
            QuickCheckView { slot, duration in
                presentAddProject(
                    ProjectPrefill(
                        startDate: slot.start,
                        durationInWorkingDays: duration,
                        status: .booked,
                        showFitMessage: true
                    )
                )
            }
        case .addProject(let prefill):
            AddProjectView(prefill: prefill) { message in
                if let message {
                    presentToast(message)
                }
            }
        }
    }

    private func presentToast(_ message: String) {
        toast = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message {
                toast = nil
            }
        }
    }
}

#Preview {
    AppRootView()
        .modelContainer(Persistence.previewContainer())
        .environment(WorkWeekStore(defaults: UserDefaults(suiteName: "au.freeday.preview.workweek") ?? .standard))
}

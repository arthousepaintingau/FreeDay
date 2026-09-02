import SwiftData
import SwiftUI

@main
struct FreeDayApp: App {
    @State private var workWeek = WorkWeekStore()

    init() {
        ProAccessStore.recordFirstLaunchIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(workWeek)
        }
        .modelContainer(Persistence.containerForCurrentProcess())
    }
}

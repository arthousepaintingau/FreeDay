import SwiftData
import SwiftUI

@main
struct FreeDayApp: App {
    @State private var workWeek = WorkWeekStore()

    init() {
        ProAccessStore.recordFirstLaunchIfNeeded()
        Task { @MainActor in
            await SubscriptionStore.shared.startAndRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(workWeek)
                .environment(SubscriptionStore.shared)
        }
        .modelContainer(Persistence.containerForCurrentProcess())
    }
}

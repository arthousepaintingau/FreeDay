import SwiftData
import SwiftUI

@main
struct FreeDayApp: App {
    private let environment = AppEnvironment.australiaDefault

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.appEnvironment, environment)
        }
        .modelContainer(Persistence.containerForCurrentProcess())
    }
}

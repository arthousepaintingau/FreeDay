import Foundation
import SwiftData

enum Persistence {
    static let schema = Schema([Project.self])

    static let modelContainer: ModelContainer = {
        do {
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create FreeDay store: \(error)")
        }
    }()

    static func containerForCurrentProcess() -> ModelContainer {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            do {
                return try inMemoryContainer()
            } catch {
                fatalError("Failed to create UI-testing store: \(error)")
            }
        }
        return modelContainer
    }

    static func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static func previewContainer(projects: [Project] = []) -> ModelContainer {
        do {
            let container = try inMemoryContainer()
            for project in projects {
                container.mainContext.insert(project)
            }
            return container
        } catch {
            fatalError("Failed to create preview store: \(error)")
        }
    }
}

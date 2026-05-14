import SwiftData
import SwiftUI

@main
struct MoryApp: App {
    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Mory model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MoryRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()

    var body: some Scene {
        WindowGroup {
            MoryRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

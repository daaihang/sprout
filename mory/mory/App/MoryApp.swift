import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
    private let memoryRepository: any MoryMemoryRepositorying

    init() {
        memoryRepository = MoryMemoryRepository(modelContext: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            MoryRootView()
                .environment(\.memoryRepository, memoryRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}

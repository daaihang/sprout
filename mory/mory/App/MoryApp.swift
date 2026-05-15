import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
    private let memoryRepository: any MoryMemoryRepositorying

    init() {
        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let apiClient = MoryAPIClient(configuration: apiConfiguration)
        let tokenProvider = MoryAuthTokenProvider(apiClient: apiClient)
        let analysisService = RemoteRecordAnalysisService(
            apiClient: apiClient,
            tokenProvider: tokenProvider
        )
        memoryRepository = MoryMemoryRepository(
            modelContext: sharedModelContainer.mainContext,
            analysisService: analysisService
        )
    }

    var body: some Scene {
        WindowGroup {
            MoryRootView()
                .environment(\.memoryRepository, memoryRepository)
        }
        .modelContainer(sharedModelContainer)
    }
}

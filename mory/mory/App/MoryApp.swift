import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
    private let memoryRepository: any MoryMemoryRepositorying
    private let credentialStore = KeychainCredentialStore()
    @State private var isSignedIn = false

    init() {
        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let apiClient = MoryAPIClient(configuration: apiConfiguration)
        let tokenProvider = MoryAuthTokenProvider(apiClient: apiClient, credentialStore: KeychainCredentialStore())
        let analysisService = RemoteRecordAnalysisService(
            apiClient: apiClient,
            tokenProvider: tokenProvider
        )
        memoryRepository = MoryMemoryRepository(
            modelContext: sharedModelContainer.mainContext,
            analysisService: analysisService
        )
        #if DEBUG
        isSignedIn = true
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if isSignedIn {
                MoryRootView()
                    .environment(\.memoryRepository, memoryRepository)
            } else {
                SignInView(credentialStore: credentialStore) {
                    isSignedIn = true
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

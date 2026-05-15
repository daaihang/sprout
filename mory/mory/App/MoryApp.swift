import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
    private let memoryRepository: any MoryMemoryRepositorying
    private let credentialStore = KeychainCredentialStore()
    @State private var isSignedIn: Bool

    init() {
        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let apiClient = MoryAPIClient(configuration: apiConfiguration)
        let store = KeychainCredentialStore()
        let tokenProvider = MoryAuthTokenProvider(apiClient: apiClient, credentialStore: store)
        let analysisService = RemoteRecordAnalysisService(
            apiClient: apiClient,
            tokenProvider: tokenProvider
        )
        memoryRepository = MoryMemoryRepository(
            modelContext: sharedModelContainer.mainContext,
            analysisService: analysisService
        )
        #if DEBUG
        _isSignedIn = State(initialValue: true)
        #else
        _isSignedIn = State(initialValue: false)
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

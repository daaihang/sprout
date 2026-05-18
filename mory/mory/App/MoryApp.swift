import SwiftUI
import SwiftData

@main
struct MoryApp: App {
    @UIApplicationDelegateAdaptor(MoryAppDelegate.self) private var appDelegate

    private let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
    private let memoryRepository: any MoryMemoryRepositorying
    private let cloudIntelligenceService: any CloudIntelligenceServing
    private let remotePushSyncService: any RemotePushSyncing
    private let credentialStore = KeychainCredentialStore()
    private let runtimeEnvironment = AppRuntimeEnvironment.current
    @State private var authManager: AuthSessionManager

    init() {
        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let client = MoryAPIClient(configuration: apiConfiguration)
        let tokenProvider = MoryAuthTokenProvider(apiClient: client, credentialStore: credentialStore)
        let analysisService = RemoteRecordAnalysisService(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        memoryRepository = MoryMemoryRepository(
            modelContext: sharedModelContainer.mainContext,
            analysisService: analysisService
        )
        cloudIntelligenceService = RemoteCloudIntelligenceClient(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        remotePushSyncService = RemotePushSyncService(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        _authManager = State(initialValue: AuthSessionManager(
            credentialStore: credentialStore,
            apiClient: client
        ))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.state {
                case .loading:
                    ProgressView()
                case .authenticated:
                    MoryRootView(
                        authManager: authManager,
                        runtimeEnvironment: runtimeEnvironment
                    )
                        .environment(\.memoryRepository, memoryRepository)
                        .environment(\.cloudIntelligenceService, cloudIntelligenceService)
                        .environment(\.remotePushSyncService, remotePushSyncService)
                case .unauthenticated:
                    SignInView(
                        credentialStore: credentialStore,
                        authManager: authManager
                    )
                }
            }
            .task {
                await authManager.checkSession()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

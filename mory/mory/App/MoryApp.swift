import SwiftUI
import Sentry
import UIKit

import SwiftData

@main
struct MoryApp: App {
    @UIApplicationDelegateAdaptor(MoryAppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let memoryRepository: any MoryMemoryRepositorying
    private let cloudIntelligenceService: any CloudIntelligenceServing
    private let remotePushSyncService: any RemotePushSyncing
    private let credentialStore: KeychainCredentialStore
    private let runtimeEnvironment: AppRuntimeEnvironment
    @State private var authManager: AuthSessionManager

    init() {
        let sharedModelContainer = MoryPersistenceStack.makeSharedModelContainer()
        let credentialStore = KeychainCredentialStore()
        let runtimeEnvironment = AppRuntimeEnvironment.current
        Self.configureSentry(runtimeEnvironment: runtimeEnvironment)
        Self.configureNavigationAppearance()

        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let client = MoryAPIClient(configuration: apiConfiguration)
        let tokenProvider = MoryAuthTokenProvider(apiClient: client, credentialStore: credentialStore)
        let analysisService = RemoteRecordAnalysisService(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        self.sharedModelContainer = sharedModelContainer
        self.credentialStore = credentialStore
        self.runtimeEnvironment = runtimeEnvironment
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

    private static func configureSentry(runtimeEnvironment: AppRuntimeEnvironment) {
        SentrySDK.start { options in
            options.dsn = "https://d624d4d4895392324795af6ca75d417f@o4511207272480768.ingest.us.sentry.io/4511413248524288"
            options.environment = runtimeEnvironment.buildChannel.rawValue

            options.sendDefaultPii = false

            switch runtimeEnvironment.distribution {
            case .debug, .development:
                options.tracesSampleRate = 1.0
                options.configureProfiling = {
                    $0.sessionSampleRate = 1.0
                    $0.lifecycle = .trace
                }
            case .testFlight:
                options.tracesSampleRate = 0.2
                options.configureProfiling = {
                    $0.sessionSampleRate = 0.05
                    $0.lifecycle = .trace
                }
            case .appStore:
                options.tracesSampleRate = 0.05
                options.configureProfiling = {
                    $0.sessionSampleRate = 0.01
                    $0.lifecycle = .trace
                }
            }

            options.experimental.enableLogs = true
        }
    }

    private static func configureNavigationAppearance() {
        UINavigationBar.appearance().prefersLargeTitles = false
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

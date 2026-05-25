import SwiftUI
import Sentry
import UIKit

import SwiftData

@main
struct MoryApp: App {
    @UIApplicationDelegateAdaptor(MoryAppDelegate.self) private var appDelegate

    private let analysisService: any ReflectionAnalysisServing
    private let cloudIntelligenceService: any CloudIntelligenceServing
    private let remotePushSyncService: any RemotePushSyncing
    private let notificationOrchestrator: NotificationOrchestrator
    private let credentialStore: KeychainCredentialStore
    private let runtimeEnvironment: AppRuntimeEnvironment
    private let ownerScopedSystemStateCoordinator = MoryOwnerScopedSystemStateCoordinator()
    @State private var authManager: AuthSessionManager
    @State private var localDataSession: MoryLocalDataSession?
    @State private var isClearingPreviousLocalDataOwner = false
    @State private var pendingExternalCaptureURL: URL?

    init() {
        let credentialStore = KeychainCredentialStore()
        let runtimeEnvironment = AppRuntimeEnvironment.current
        Self.configureSentry(runtimeEnvironment: runtimeEnvironment)
        Self.configureNavigationAppearance()

        let apiConfiguration = MoryAPIConfiguration.fromBundle()
        let client = MoryAPIClient(configuration: apiConfiguration)
        let tokenProvider = MoryAuthTokenProvider(apiClient: client, credentialStore: credentialStore)
        let analysisService = RemoteReflectionAnalysisService(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        self.credentialStore = credentialStore
        self.runtimeEnvironment = runtimeEnvironment
        self.analysisService = analysisService
        cloudIntelligenceService = RemoteCloudIntelligenceClient(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        let remotePushSyncService = RemotePushSyncService(
            apiClient: client,
            tokenProvider: tokenProvider
        )
        self.remotePushSyncService = remotePushSyncService
        notificationOrchestrator = .live(remotePushSyncService: remotePushSyncService)
        _authManager = State(initialValue: AuthSessionManager(
            credentialStore: credentialStore,
            apiClient: client
        ))
    }

    private static func configureSentry(runtimeEnvironment: AppRuntimeEnvironment) {
        SentrySDK.start { options in
            options.dsn = Bundle.main.infoDictionary?["SentryDSN"] as? String ?? ""
            options.environment = runtimeEnvironment.buildChannel.rawValue
            options.releaseName = "\(runtimeEnvironment.bundleIdentifier)@\(runtimeEnvironment.version)+\(runtimeEnvironment.buildNumber)"
            options.dist = runtimeEnvironment.buildNumber
            options.debug = runtimeEnvironment.distribution == .debug

            options.sendDefaultPii = false
            options.enableAutoSessionTracking = true

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

        SentrySDK.configureScope { scope in
            scope.setTag(value: runtimeEnvironment.bundleIdentifier, key: "bundle_identifier")
            scope.setTag(value: runtimeEnvironment.distribution.rawValue, key: "distribution")
            scope.setTag(value: runtimeEnvironment.buildChannel.rawValue, key: "build_channel")
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
                    authenticatedRoot
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
            .onOpenURL { url in
                pendingExternalCaptureURL = url
            }
            .onReceive(NotificationCenter.default.publisher(for: .moryAuthSessionExpired)) { notification in
                Task {
                    let reason = notification.userInfo?[MoryAuthSessionExpiredUserInfoKey.reason] as? String
                    await authManager.handleSessionExpired(reason: reason)
                }
            }
            .onChange(of: authManager.localDataOwnerID) { _, ownerID in
                if localDataSession?.ownerID != ownerID {
                    let previousSession = localDataSession
                    localDataSession = nil

                    if let previousSession {
                        isClearingPreviousLocalDataOwner = true
                        Task {
                            await ownerScopedSystemStateCoordinator.clearActiveOwnerSystemState(
                                repository: previousSession.memoryRepository
                            )
                            isClearingPreviousLocalDataOwner = false
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var authenticatedRoot: some View {
        if isClearingPreviousLocalDataOwner {
            ProgressView()
        } else if let ownerID = authManager.localDataOwnerID {
            if let localDataSession, localDataSession.ownerID == ownerID {
                MoryRootView(
                    authManager: authManager,
                    runtimeEnvironment: runtimeEnvironment,
                    pendingExternalCaptureURL: $pendingExternalCaptureURL
                )
                .environment(\.memoryRepository, localDataSession.memoryRepository)
                .environment(\.cloudIntelligenceService, cloudIntelligenceService)
                .environment(\.remotePushSyncService, remotePushSyncService)
                .environment(\.notificationOrchestrator, notificationOrchestrator)
                .environment(\.localDataDiagnostics, localDataSession.diagnostics)
                .modelContainer(localDataSession.modelContainer)
            } else {
                ProgressView()
                    .task(id: ownerID) {
                        let session = MoryLocalDataSession(
                            ownerID: ownerID,
                            analysisService: analysisService,
                            cloudIntelligenceService: cloudIntelligenceService,
                            notificationOrchestrator: notificationOrchestrator
                        )
                        await ownerScopedSystemStateCoordinator.prepareActiveOwner(
                            ownerID: ownerID,
                            repository: session.memoryRepository,
                            remotePushSyncService: remotePushSyncService
                        )
                        appDelegate.backgroundTaskCoordinator.configure(
                            repository: session.memoryRepository,
                            cloudService: cloudIntelligenceService,
                            remotePushSyncService: remotePushSyncService,
                            notificationOrchestrator: notificationOrchestrator
                        )
                        appDelegate.backgroundTaskCoordinator.scheduleIfNeeded()
                        localDataSession = session
                    }
            }
        } else {
            ProgressView()
        }
    }
}

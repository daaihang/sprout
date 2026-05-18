import Combine
import SwiftUI

struct MoryRootView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService
    @Environment(\.remotePushSyncService) private var remotePushSyncService
    @AppStorage(MoryOnboardingStep.completionStorageKey) private var hasCompletedOnboarding = false
    @StateObject private var notificationInbox = NotificationInteractionInbox.shared
    @State private var selectedTab: MoryAppTab = .today
    @State private var isPresentingSettings = false
    @State private var unifiedCaptureSeed: UnifiedCaptureSeed?
    @State private var tabRefreshID = UUID()
    @State private var pendingHomeRoute: HomeRoute?
    @State private var pendingMemoriesRoute: MemoriesRoute?
    @State private var pendingInsightsRoute: InsightsRoute?
    @State private var didRunStartupRecovery = false
    private let notificationInteractionService = NotificationInteractionService()
    private let startupRecoveryService = AppIntelligenceRecoveryService()

    init(
        authManager: AuthSessionManager? = nil,
        runtimeEnvironment: AppRuntimeEnvironment = .current
    ) {
        self.authManager = authManager
        self.runtimeEnvironment = runtimeEnvironment
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(
                LocalizedStringKey(MoryAppTab.today.titleKey),
                systemImage: MoryAppTab.today.systemImage,
                value: MoryAppTab.today
            ) {
                tabRoot {
                    HomeScreen(surface: .home, requestedRoute: $pendingHomeRoute)
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.memories.titleKey),
                systemImage: MoryAppTab.memories.systemImage,
                value: MoryAppTab.memories
            ) {
                tabRoot {
                    MemoriesRootScreen(requestedRoute: $pendingMemoriesRoute)
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.insights.titleKey),
                systemImage: MoryAppTab.insights.systemImage,
                value: MoryAppTab.insights
            ) {
                tabRoot {
                    InsightsRootScreen(requestedRoute: $pendingInsightsRoute)
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.search.titleKey),
                systemImage: MoryAppTab.search.systemImage,
                value: MoryAppTab.search,
                role: .search
            ) {
                tabRoot {
                    SearchScreen()
                }
                .id(tabRefreshID)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            QuickCaptureToolbar(
                onTextCapture: { unifiedCaptureSeed = .empty },
                onPhotoCapture: { unifiedCaptureSeed = .photoCapture },
                onVoiceCaptureReady: { result in unifiedCaptureSeed = .voice(result) }
            )
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsScreen(
                authManager: authManager,
                runtimeEnvironment: runtimeEnvironment
            )
        }
        .sheet(item: $unifiedCaptureSeed) { seed in
            UnifiedCaptureComposerView(seed: seed) {
                tabRefreshID = UUID()
            }
        }
        .fullScreenCover(isPresented: onboardingPresentation) {
            MoryOnboardingView(
                onSkip: completeOnboarding,
                onStartFirstMemory: startFirstMemoryFromOnboarding
            )
        }
        .onReceive(notificationInbox.$latestEvent.compactMap { $0 }) { event in
            Task {
                await handleNotificationInteraction(event)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moryAPNSTokenDidUpdate)) { _ in
            Task {
                await syncRemotePushRegistration(force: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moryNotificationPreferencesDidChange)) { _ in
            Task {
                await syncRemotePushRegistration(force: true)
            }
        }
        .task {
            await recoverStartupIntelligenceIfNeeded()
        }
    }

    private func tabRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    settingsToolbar
                }
        }
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPresentingSettings = true
            } label: {
                Label("settings.nav.title", systemImage: "person.crop.circle")
            }
            .accessibilityLabel(Text("settings.nav.title"))
            .accessibilityHint(Text("settings.nav.hint"))
        }
    }

    private var onboardingPresentation: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasCompletedOnboarding = true
                }
            }
        )
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    private func startFirstMemoryFromOnboarding() {
        hasCompletedOnboarding = true
        DispatchQueue.main.async {
            unifiedCaptureSeed = .empty
        }
    }

    private func handleNotificationInteraction(_ event: NotificationInteractionEvent) async {
        defer {
            notificationInbox.consume(eventID: event.id)
        }

        do {
            let result = try notificationInteractionService.handle(
                event: event,
                repository: memoryRepository
            )
            await remotePushSyncService.writeBackInteraction(event)
            guard let route = result.route else { return }
            apply(route)
        } catch {
            assertionFailure("Failed to handle notification interaction: \(error)")
        }
    }

    private func apply(_ route: NotificationInteractionRoute) {
        if let deepLink = route.deepLink {
            apply(deepLink)
            return
        }

        switch route.destination {
        case .home:
            selectedTab = .today
        case .memories:
            selectedTab = .memories
        case .insights:
            selectedTab = .insights
        case .search:
            selectedTab = .search
        }
    }

    private func apply(_ deepLink: MoryDeepLinkRoute) {
        switch deepLink {
        case let .home(route):
            selectedTab = .today
            pendingHomeRoute = route
        case let .memories(route):
            selectedTab = .memories
            pendingMemoriesRoute = route
        case let .insights(route):
            selectedTab = .insights
            pendingInsightsRoute = route
        case .search:
            selectedTab = .search
        }
    }

    private func recoverStartupIntelligenceIfNeeded() async {
        guard !didRunStartupRecovery else { return }
        didRunStartupRecovery = true

        _ = await startupRecoveryService.recoverAfterLaunch(
            repository: memoryRepository,
            cloudIntelligenceService: cloudIntelligenceService
        )
        remotePushSyncService.registerSystemRemoteNotificationsIfNeeded(repository: memoryRepository)
        await syncRemotePushRegistration(force: true)
    }

    private func syncRemotePushRegistration(force: Bool) async {
        remotePushSyncService.registerSystemRemoteNotificationsIfNeeded(repository: memoryRepository)
        await remotePushSyncService.syncRegistrationIfPossible(
            repository: memoryRepository,
            force: force
        )
    }
}

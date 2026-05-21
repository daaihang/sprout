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
    @State private var isEditingHomeBoard = false
    @State private var isPresentingMemoriesFilters = false
    @State private var searchQuery = ""
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
                tabRoot(for: .today) {
                    HomeScreen(
                        surface: .home,
                        requestedRoute: $pendingHomeRoute,
                        isEditingHomeBoard: $isEditingHomeBoard
                    )
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.memories.titleKey),
                systemImage: MoryAppTab.memories.systemImage,
                value: MoryAppTab.memories
            ) {
                tabRoot(for: .memories) {
                    MemoriesRootScreen(
                        requestedRoute: $pendingMemoriesRoute,
                        isPresentingFilterSheet: $isPresentingMemoriesFilters
                    )
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.insights.titleKey),
                systemImage: MoryAppTab.insights.systemImage,
                value: MoryAppTab.insights
            ) {
                tabRoot(for: .insights) {
                    InsightsRootScreen(requestedRoute: $pendingInsightsRoute)
                }
                .id(tabRefreshID)
            }

            Tab(value: MoryAppTab.search, role: .search) {
                tabRoot(for: .search) {
                    SearchScreen(query: $searchQuery)
                }
                .id(tabRefreshID)
            }
        }
        .tabViewSearchActivation(.searchTabSelection)
        .tabBarMinimizeBehavior(.onScrollDown)
        .moryTabViewBottomAccessory {
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
                await remotePushSyncService.syncRegistrationIfPossible(
                    repository: memoryRepository,
                    force: true
                )
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
        .onChange(of: selectedTab) { _, tab in
            if tab != .today {
                isEditingHomeBoard = false
            }
        }
    }

    @ViewBuilder
    private func tabRoot<Content: View>(
        for tab: MoryAppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if tab == .search {
            tabNavigationStack(for: tab, content: content)
                .searchable(text: $searchQuery, prompt: "search.prompt")
        } else {
            tabNavigationStack(for: tab, content: content)
        }
    }

    private func tabNavigationStack<Content: View>(
        for tab: MoryAppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            tabContent(for: tab, content: content)
        }
    }

    private func tabContent<Content: View>(
        for tab: MoryAppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: rootBottomContentInset)
                    .accessibilityHidden(true)
            }
            .navigationTitle(LocalizedStringKey(tab.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                rootToolbar(for: tab)
            }
    }

    private var rootBottomContentInset: CGFloat {
        58
    }

    @ToolbarContentBuilder
    private func rootToolbar(for tab: MoryAppTab) -> some ToolbarContent {
        switch tab {
        case .today:
            ToolbarItem(placement: .topBarLeading) {
                Button {
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .disabled(true)
                .accessibilityLabel(Text(verbatim: "Reserved action"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingHomeBoard.toggle()
                } label: {
                    Image(systemName: isEditingHomeBoard ? "checkmark.circle.fill" : "square.and.pencil")
                }
                .accessibilityLabel(Text(verbatim: isEditingHomeBoard ? "Done editing board" : "Edit board"))
            }
        case .memories:
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isPresentingMemoriesFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(Text("memories.filters.title"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    TimelineScreen()
                        .moryHidesTabChrome()
                } label: {
                    Image(systemName: "clock")
                }
                .accessibilityLabel(Text("timeline.nav.title"))
            }
        case .insights, .search:
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
    }

    private var settingsButton: some View {
        Button {
            isPresentingSettings = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel(Text("settings.nav.title"))
        .accessibilityHint(Text("settings.nav.hint"))
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

extension View {
    func moryHidesTabChrome() -> some View {
        self
    }

    @ViewBuilder
    func moryTabViewBottomAccessory<Content: View>(
        isVisible: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26.1, *) {
            tabViewBottomAccessory(isEnabled: isVisible) {
                content()
            }
        } else if isVisible {
            tabViewBottomAccessory {
                content()
            }
        } else {
            self
        }
    }
}

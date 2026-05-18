import Combine
import SwiftUI

struct MoryRootView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @Environment(\.memoryRepository) private var memoryRepository
    @AppStorage(MoryOnboardingStep.completionStorageKey) private var hasCompletedOnboarding = false
    @StateObject private var notificationInbox = NotificationInteractionInbox.shared
    @State private var selectedTab: MoryAppTab = .today
    @State private var isPresentingSettings = false
    @State private var unifiedCaptureSeed: UnifiedCaptureSeed?
    @State private var tabRefreshID = UUID()
    private let notificationInteractionService = NotificationInteractionService()

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
                    HomeScreen(surface: .home)
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.memories.titleKey),
                systemImage: MoryAppTab.memories.systemImage,
                value: MoryAppTab.memories
            ) {
                tabRoot {
                    MemoriesRootScreen()
                }
                .id(tabRefreshID)
            }

            Tab(
                LocalizedStringKey(MoryAppTab.insights.titleKey),
                systemImage: MoryAppTab.insights.systemImage,
                value: MoryAppTab.insights
            ) {
                tabRoot {
                    InsightsRootScreen()
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
            guard let route = result.route else { return }
            selectedTab = tab(for: route.destination)
            tabRefreshID = UUID()
        } catch {
            assertionFailure("Failed to handle notification interaction: \(error)")
        }
    }

    private func tab(for destination: NotificationInteractionDestination) -> MoryAppTab {
        switch destination {
        case .home:
            return .today
        case .memories:
            return .memories
        case .insights:
            return .insights
        case .search:
            return .search
        }
    }
}

import SwiftUI

struct MoryRootView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @AppStorage(MoryOnboardingStep.completionStorageKey) private var hasCompletedOnboarding = false
    @State private var selectedTab: MoryAppTab = .today
    @State private var isPresentingSettings = false
    @State private var unifiedCaptureSeed: UnifiedCaptureSeed?
    @State private var tabRefreshID = UUID()

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
}

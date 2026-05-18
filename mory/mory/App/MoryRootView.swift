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
            tabRoot {
                HomeScreen(surface: .home)
            }
            .id(tabRefreshID)
            .tabItem {
                Label(LocalizedStringKey(MoryAppTab.today.titleKey), systemImage: MoryAppTab.today.systemImage)
            }
            .tag(MoryAppTab.today)

            tabRoot {
                MemoriesRootScreen()
            }
            .id(tabRefreshID)
            .tabItem {
                Label(LocalizedStringKey(MoryAppTab.memories.titleKey), systemImage: MoryAppTab.memories.systemImage)
            }
            .tag(MoryAppTab.memories)

            tabRoot {
                InsightsRootScreen()
            }
            .id(tabRefreshID)
            .tabItem {
                Label(LocalizedStringKey(MoryAppTab.insights.titleKey), systemImage: MoryAppTab.insights.systemImage)
            }
            .tag(MoryAppTab.insights)
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
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    QuickCaptureToolbar(
                        onTextCapture: { unifiedCaptureSeed = .empty },
                        onPhotoCapture: { unifiedCaptureSeed = .photoCapture },
                        onMoreCapture: { unifiedCaptureSeed = .empty },
                        onVoiceCaptureReady: { result in unifiedCaptureSeed = .voice(result) },
                    )
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

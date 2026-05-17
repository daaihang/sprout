import SwiftUI

struct MoryRootView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @State private var selectedTab: MoryAppTab = .today
    @State private var isPresentingSettings = false
    @State private var isPresentingQuickTextCapture = false
    @State private var isPresentingFullCapture = false
    @State private var quickVoiceResult: QuickVoiceCaptureResult?
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
        .sheet(isPresented: $isPresentingFullCapture) {
            CaptureComposerView {
                tabRefreshID = UUID()
            }
        }
        .sheet(isPresented: $isPresentingQuickTextCapture) {
            QuickTextCaptureView {
                tabRefreshID = UUID()
            }
        }
        .sheet(item: $quickVoiceResult) { result in
            QuickVoiceReviewView(result: result) {
                tabRefreshID = UUID()
            }
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
                        onTextCapture: { isPresentingQuickTextCapture = true },
                        onMoreCapture: { isPresentingFullCapture = true },
                        onVoiceCaptureReady: { result in quickVoiceResult = result }
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
        }
    }
}

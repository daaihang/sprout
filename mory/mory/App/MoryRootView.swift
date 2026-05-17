import SwiftUI

struct MoryRootView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @State private var selectedTab: MoryAppTab = .today
    @State private var isPresentingSettings = false

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
            .tabItem {
                Label(LocalizedStringKey(MoryAppTab.today.titleKey), systemImage: MoryAppTab.today.systemImage)
            }
            .tag(MoryAppTab.today)

            tabRoot {
                MemoriesRootScreen()
            }
            .tabItem {
                Label(LocalizedStringKey(MoryAppTab.memories.titleKey), systemImage: MoryAppTab.memories.systemImage)
            }
            .tag(MoryAppTab.memories)

            tabRoot {
                InsightsRootScreen()
            }
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
        }
    }
}

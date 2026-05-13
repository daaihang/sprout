import SwiftUI
import SwiftData

@main
struct sproutApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var localization = AppLocalization.shared
    @State private var subscriptionManager = SubscriptionManager()
    @State private var authSessionManager = AuthSessionManager()
    @State private var biometricLockManager = BiometricLockManager()
    @State private var installExperienceStore = InstallExperienceStore()
    @State private var onboardingPreviewService = OnboardingPreviewService()

    var sharedModelContainer: ModelContainer = {
        #if targetEnvironment(simulator)
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .none
        #else
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .automatic
        #endif

        let schema = Schema([
            Record.self,
            Person.self,
            Decision.self,
            MediaCard.self,
            DailyQuestion.self,
            Activity.self,
            DashboardSystemCardConfig.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: cloudKitDatabase
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(\.locale, localization.locale)
                .environment(localization)
                .environment(subscriptionManager)
                .environment(authSessionManager)
                .environment(biometricLockManager)
                .environment(installExperienceStore)
                .environment(onboardingPreviewService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            localization.refreshIfNeeded()
            Task {
                await authSessionManager.refreshSessionIfNeeded()
                await biometricLockManager.authenticateIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                biometricLockManager.lock()
            }
        }
    }
}

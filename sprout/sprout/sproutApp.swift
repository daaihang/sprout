import SwiftUI
import SwiftData

@main
struct sproutApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var localization = AppLocalization.shared
    @State private var subscriptionManager = SubscriptionManager()

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
            ContentView()
                .environment(\.locale, localization.locale)
                .environment(localization)
                .environment(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            localization.refreshIfNeeded()
        }
    }
}

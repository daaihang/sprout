import SwiftUI
import SwiftData

@main
struct sproutApp: App {
    @State private var subscriptionManager = SubscriptionManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Record.self,
            Person.self,
            Decision.self,
            MediaCard.self,
            DailyQuestion.self,
            Activity.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
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
                .environment(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

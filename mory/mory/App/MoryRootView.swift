import SwiftUI

struct MoryRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeScreen(surface: .home)
            }
            .tabItem {
                Label("tab.home", systemImage: "house")
            }

            NavigationStack {
                HomeScreen(surface: .memories)
            }
            .tabItem {
                Label("tab.memories", systemImage: "square.stack")
            }

            NavigationStack {
                TimelineScreen()
            }
            .tabItem {
                Label("tab.timeline", systemImage: "clock")
            }

            NavigationStack {
                PeopleScreen()
            }
            .tabItem {
                Label("tab.people", systemImage: "person.2")
            }

            NavigationStack {
                ArcsScreen()
            }
            .tabItem {
                Label("tab.arcs", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }

            NavigationStack {
                SearchScreen()
            }
            .tabItem {
                Label("tab.search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ReflectionsScreen()
            }
            .tabItem {
                Label("tab.reflections", systemImage: "sparkles.rectangle.stack")
            }

#if DEBUG
            NavigationStack {
                DebugDiagnosticsView()
            }
            .tabItem {
                Label("tab.debug", systemImage: "ladybug")
            }
#endif
        }
    }
}

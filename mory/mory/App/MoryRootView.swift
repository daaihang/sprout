import SwiftUI

struct MoryRootView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeScreen(surface: .home)
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                HomeScreen(surface: .memories)
            }
            .tabItem {
                Label("Memories", systemImage: "square.stack")
            }

            NavigationStack {
                PeopleScreen()
            }
            .tabItem {
                Label("People", systemImage: "person.2")
            }

            NavigationStack {
                ArcsScreen()
            }
            .tabItem {
                Label("Arcs", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }

            NavigationStack {
                SearchScreen()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                ReflectionsScreen()
            }
            .tabItem {
                Label("Reflections", systemImage: "sparkles.rectangle.stack")
            }

#if DEBUG
            NavigationStack {
                DebugDiagnosticsView()
            }
            .tabItem {
                Label("Debug", systemImage: "ladybug")
            }
#endif
        }
    }
}

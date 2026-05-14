import SwiftData
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
                FeaturePlaceholderScreen(
                    title: "People",
                    description: "People will be powered by the entity graph already defined in the new architecture."
                )
            }
            .tabItem {
                Label("People", systemImage: "person.2")
            }

            NavigationStack {
                FeaturePlaceholderScreen(
                    title: "Arcs",
                    description: "Temporal arcs land here after the record and artifact path is stable."
                )
            }
            .tabItem {
                Label("Arcs", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }

            NavigationStack {
                FeaturePlaceholderScreen(
                    title: "Search",
                    description: "Search will query artifacts, entities, arcs, and reflections from the same memory stack."
                )
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
    }
}

private struct FeaturePlaceholderScreen: View {
    let title: String
    let description: String

    var body: some View {
        List {
            Section(title) {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
    }
}

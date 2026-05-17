import SwiftUI

struct MemoriesRootScreen: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    HomeScreen(surface: .memories)
                } label: {
                    MoryHubRow(
                        title: "memories.hub.all.title",
                        subtitle: "memories.hub.all.subtitle",
                        systemImage: "square.stack"
                    )
                }

                NavigationLink {
                    TimelineScreen()
                } label: {
                    MoryHubRow(
                        title: "memories.hub.timeline.title",
                        subtitle: "memories.hub.timeline.subtitle",
                        systemImage: "clock"
                    )
                }

                NavigationLink {
                    SearchScreen()
                } label: {
                    MoryHubRow(
                        title: "memories.hub.search.title",
                        subtitle: "memories.hub.search.subtitle",
                        systemImage: "magnifyingglass"
                    )
                }
            } footer: {
                Text("memories.hub.footer")
            }
        }
        .navigationTitle("tab.memories")
    }
}

struct MoryHubRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: MorySpacing.medium) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, MorySpacing.small)
    }
}

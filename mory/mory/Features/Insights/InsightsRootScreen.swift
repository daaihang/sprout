import SwiftUI

struct InsightsRootScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var snapshot: InsightsPresentationSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ArcsScreen()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.storylines.title",
                        subtitle: "insights.hub.storylines.subtitle",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }

                NavigationLink {
                    ReflectionsScreen()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.reflections.title",
                        subtitle: "insights.hub.reflections.subtitle",
                        systemImage: "sparkles"
                    )
                }

                NavigationLink {
                    SearchScreen()
                } label: {
                    MoryHubRow(
                        title: "Search",
                        subtitle: "Search memories, people, places, themes, decisions, storylines, and reflections.",
                        systemImage: "magnifyingglass"
                    )
                }
            } footer: {
                Text("Insights are based on saved memories, graph links, storylines, and reflections.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                Section("Overview") {
                    HStack {
                        InsightMetricView(title: "Storylines", value: snapshot.totalStorylineCount)
                        InsightMetricView(title: "Reflections", value: snapshot.totalReflectionCount)
                        InsightMetricView(title: "Entities", value: snapshot.totalEntityCount)
                    }
                }

                if let highlighted = snapshot.highlightedStoryline {
                    Section("Highlighted Storyline") {
                        NavigationLink {
                            ArcDetailView(arcID: highlighted.arc.id)
                        } label: {
                            StorylineRow(summary: highlighted)
                        }
                    }
                }

                insightSection(
                    title: "Storylines",
                    empty: "No storylines yet.",
                    rows: snapshot.storylines
                ) { item in
                    NavigationLink {
                        ArcDetailView(arcID: item.arc.id)
                    } label: {
                        StorylineRow(summary: item)
                    }
                }

                insightSection(
                    title: "Suggested Reflections",
                    empty: "No suggested reflections yet.",
                    rows: snapshot.suggestedReflections
                ) { item in
                    NavigationLink {
                        ReflectionDetailView(reflectionID: item.reflection.id)
                    } label: {
                        ReflectionInsightRow(summary: item)
                    }
                }

                insightSection(
                    title: "People",
                    empty: "No people yet.",
                    rows: snapshot.people
                ) { item in
                    NavigationLink {
                        PersonDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "Places",
                    empty: "No places yet.",
                    rows: snapshot.places
                ) { item in
                    NavigationLink {
                        EntityDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "Themes",
                    empty: "No themes yet.",
                    rows: snapshot.themes
                ) { item in
                    NavigationLink {
                        EntityDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "Decisions",
                    empty: "No decisions yet.",
                    rows: snapshot.decisions
                ) { item in
                    NavigationLink {
                        EntityDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                if !snapshot.savedReflections.isEmpty {
                    insightSection(
                        title: "Saved Reflections",
                        empty: "",
                        rows: snapshot.savedReflections
                    ) { item in
                        NavigationLink {
                            ReflectionDetailView(reflectionID: item.reflection.id)
                        } label: {
                            ReflectionInsightRow(summary: item)
                        }
                    }
                }
            } else {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("tab.insights")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchInsightsPresentation(limitPerSection: 5)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func insightSection<Row: Identifiable, Content: View>(
        title: String,
        empty: String,
        rows: [Row],
        @ViewBuilder content: @escaping (Row) -> Content
    ) -> some View {
        Section(title) {
            if rows.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    content(row)
                }
            }
        }
    }
}

private struct InsightMetricView: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StorylineRow: View {
    let summary: TemporalArcSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.arc.title)
                    .font(.headline)
                Spacer()
                Text(summary.arc.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(summary.arc.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("\(summary.arc.sourceRecordIDs.count) source memories")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !summary.relatedMemories.isEmpty {
                Text(summary.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ReflectionInsightRow: View {
    let summary: ReflectionSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.reflection.title)
                    .font(.headline)
                Spacer()
                Text(summary.reflection.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(summary.reflection.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Text("\(summary.relatedMemories.count) visible sources")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EntityInsightRow: View {
    let snapshot: EntityDetailSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.entity.displayName)
                    .font(.headline)
                Spacer()
                Text(snapshot.entity.kind.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let summary = snapshot.entity.summary.trimmedOrNil {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("\(snapshot.relatedMemories.count) memories · \(snapshot.relatedArcs.count) storylines · \(snapshot.relatedReflections.count) reflections")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

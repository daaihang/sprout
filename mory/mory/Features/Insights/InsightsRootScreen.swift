import SwiftUI

struct InsightsRootScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var snapshot: InsightsPresentationSnapshot?
    @State private var isPresentingComposer = false
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
                        title: "insights.hub.search.title",
                        subtitle: "insights.hub.search.subtitle",
                        systemImage: "magnifyingglass"
                    )
                }
            } footer: {
                Text("insights.hub.footer")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                if snapshot.isPubliclyEmpty {
                    Section {
                        MoryPublicEmptyStateView(
                            state: .insights,
                            onAction: { isPresentingComposer = true }
                        )
                    }
                }

                Section("insights.section.overview") {
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            InsightMetricView(title: "insights.metric.storylines", value: snapshot.totalStorylineCount)
                            InsightMetricView(title: "insights.metric.reflections", value: snapshot.totalReflectionCount)
                            InsightMetricView(title: "insights.metric.entities", value: snapshot.totalEntityCount)
                        }
                        VStack(spacing: MorySpacing.small) {
                            InsightMetricView(title: "insights.metric.storylines", value: snapshot.totalStorylineCount)
                            InsightMetricView(title: "insights.metric.reflections", value: snapshot.totalReflectionCount)
                            InsightMetricView(title: "insights.metric.entities", value: snapshot.totalEntityCount)
                        }
                    }
                }

                if let highlighted = snapshot.highlightedStoryline {
                    Section("insights.section.highlightedStoryline") {
                        NavigationLink {
                            ArcDetailView(arcID: highlighted.arc.id)
                        } label: {
                            StorylineRow(summary: highlighted)
                        }
                    }
                }

                insightSection(
                    title: "insights.section.storylines",
                    empty: "empty.insights.storylines",
                    rows: snapshot.storylines
                ) { item in
                    NavigationLink {
                        ArcDetailView(arcID: item.arc.id)
                    } label: {
                        StorylineRow(summary: item)
                    }
                }

                insightSection(
                    title: "insights.section.suggestedReflections",
                    empty: "empty.insights.reflections",
                    rows: snapshot.suggestedReflections
                ) { item in
                    NavigationLink {
                        ReflectionDetailView(reflectionID: item.reflection.id)
                    } label: {
                        ReflectionInsightRow(summary: item)
                    }
                }

                insightSection(
                    title: "insights.section.people",
                    empty: "empty.insights.people",
                    rows: snapshot.people
                ) { item in
                    NavigationLink {
                        PersonDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "insights.section.places",
                    empty: "empty.insights.places",
                    rows: snapshot.places
                ) { item in
                    NavigationLink {
                        EntityDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "insights.section.themes",
                    empty: "empty.insights.themes",
                    rows: snapshot.themes
                ) { item in
                    NavigationLink {
                        EntityDetailView(entityID: item.entity.id)
                    } label: {
                        EntityInsightRow(snapshot: item)
                    }
                }

                insightSection(
                    title: "insights.section.decisions",
                    empty: "empty.insights.decisions",
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
                        title: "insights.section.savedReflections",
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
        .sheet(isPresented: $isPresentingComposer) {
            CaptureComposerView {
                Task { await load() }
            }
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
        title: LocalizedStringKey,
        empty: LocalizedStringKey,
        rows: [Row],
        @ViewBuilder content: @escaping (Row) -> Content
    ) -> some View {
        Section(title) {
            if rows.isEmpty {
                Text(empty)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(rows) { row in
                    content(row)
                }
            }
        }
    }
}

private struct InsightMetricView: View {
    let title: LocalizedStringKey
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .moryCard(tone: .neutral)
        .accessibilityElement(children: .combine)
    }
}

private struct StorylineRow: View {
    let summary: TemporalArcSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(summary.arc.title)
                        .font(.headline)
                    Spacer()
                    Text(summary.arc.status.presentationLabel)
                        .moryPill(tone: .storyline)
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(summary.arc.title)
                        .font(.headline)
                    Text(summary.arc.status.presentationLabel)
                        .moryPill(tone: .storyline)
                }
            }
            Text(summary.arc.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("insights.storyline.sourceCount \(summary.arc.sourceRecordIDs.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !summary.relatedMemories.isEmpty {
                Text(summary.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .moryCard(tone: .storyline)
        .accessibilityElement(children: .combine)
    }
}

private struct ReflectionInsightRow: View {
    let summary: ReflectionSummarySnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(summary.reflection.title)
                        .font(.headline)
                    Spacer()
                    Text(summary.reflection.status.label)
                        .moryPill(tone: .reflection)
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(summary.reflection.title)
                        .font(.headline)
                    Text(summary.reflection.status.label)
                        .moryPill(tone: .reflection)
                }
            }
            Text(summary.reflection.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("insights.reflection.sourceCount \(summary.relatedMemories.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .moryCard(tone: .reflection)
        .accessibilityElement(children: .combine)
    }
}

private struct EntityInsightRow: View {
    let snapshot: EntityDetailSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(snapshot.entity.displayName)
                        .font(.headline)
                    Spacer()
                    Text(snapshot.entity.kind.presentationLabel)
                        .moryPill(tone: .entity)
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(snapshot.entity.displayName)
                        .font(.headline)
                    Text(snapshot.entity.kind.presentationLabel)
                        .moryPill(tone: .entity)
                }
            }
            if let summary = snapshot.entity.summary.trimmedOrNil {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("insights.entity.stats \(snapshot.relatedMemories.count) \(snapshot.relatedArcs.count) \(snapshot.relatedReflections.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .moryCard(tone: .entity)
        .accessibilityElement(children: .combine)
    }
}

private extension TemporalArcStatus {
    var presentationLabel: String {
        switch self {
        case .candidate: return String(localized: "arc.status.candidate")
        case .accepted: return String(localized: "arc.status.accepted")
        case .archived: return String(localized: "arc.status.archived")
        case .merged: return String(localized: "arc.status.merged")
        }
    }
}

private extension EntityKind {
    var presentationLabel: String {
        switch self {
        case .person: return String(localized: "entity.kind.person")
        case .place: return String(localized: "entity.kind.place")
        case .theme: return String(localized: "entity.kind.theme")
        case .decision: return String(localized: "entity.kind.decision")
        case .activity: return String(localized: "entity.kind.activity")
        case .object: return String(localized: "entity.kind.object")
        }
    }
}

private extension InsightsPresentationSnapshot {
    var isPubliclyEmpty: Bool {
        highlightedStoryline == nil
            && storylines.isEmpty
            && suggestedReflections.isEmpty
            && savedReflections.isEmpty
            && people.isEmpty
            && places.isEmpty
            && themes.isEmpty
            && decisions.isEmpty
    }
}

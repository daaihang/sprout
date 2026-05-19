import SwiftUI

struct InsightsRootScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @Binding private var requestedRoute: InsightsRoute?
    @State private var snapshot: InsightsPresentationSnapshot?
    @State private var isPresentingComposer = false
    @State private var errorMessage: String?
    @State private var selectedRoute: InsightsRoute?

    init(requestedRoute: Binding<InsightsRoute?> = .constant(nil)) {
        _requestedRoute = requestedRoute
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ArcsScreen()
                        .moryHidesTabChrome()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.storylines.title",
                        subtitle: "insights.hub.storylines.subtitle",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }

                NavigationLink {
                    ReflectionsScreen()
                        .moryHidesTabChrome()
                } label: {
                    MoryHubRow(
                        title: "insights.hub.reflections.title",
                        subtitle: "insights.hub.reflections.subtitle",
                        systemImage: "sparkles"
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
                                .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                            .moryHidesTabChrome()
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
                                .moryHidesTabChrome()
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
        .navigationDestination(item: $selectedRoute) { route in
            switch route {
            case let .arc(arcID):
                ArcDetailView(arcID: arcID)
                    .moryHidesTabChrome()
            case let .reflection(reflectionID):
                ReflectionDetailView(reflectionID: reflectionID)
                    .moryHidesTabChrome()
            case let .entity(entityID):
                EntityDetailView(entityID: entityID)
                    .moryHidesTabChrome()
            }
        }
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .onAppear {
            consumeRequestedRouteIfNeeded()
        }
        .onChange(of: requestedRoute) { _, _ in
            consumeRequestedRouteIfNeeded()
        }
        .sheet(isPresented: $isPresentingComposer) {
            UnifiedCaptureComposerView(seed: .empty) {
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

    private func consumeRequestedRouteIfNeeded() {
        guard let requestedRoute else { return }
        selectedRoute = requestedRoute
        self.requestedRoute = nil
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
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(summary.arc.title)
                        .font(.headline)
                    Text(summary.arc.status.presentationLabel)
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
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(summary.reflection.title)
                        .font(.headline)
                    Text(summary.reflection.status.label)
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
                }
                VStack(alignment: .leading, spacing: MorySpacing.xSmall) {
                    Text(snapshot.entity.displayName)
                        .font(.headline)
                    Text(snapshot.entity.kind.presentationLabel)
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

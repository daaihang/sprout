import SwiftUI

struct MemoriesRootScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var selectedArtifactKind: ArtifactKind?
    @State private var selectedPipelineStage: MemoryPipelineStage?
    @State private var selectedContext: MemoryLibraryContextFilter = .any
    @State private var selectedInsight: MemoryLibraryInsightFilter = .any
    @State private var snapshot: MemoryLibrarySnapshot?
    @State private var errorMessage: String?

    private var filter: MemoryLibraryFilter {
        MemoryLibraryFilter(
            artifactKinds: selectedArtifactKind.map { [$0] } ?? [],
            pipelineStages: selectedPipelineStage.map { [$0] } ?? [],
            context: selectedContext,
            insight: selectedInsight
        )
    }

    var body: some View {
        List {
            Section {
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
                Text("Memories now shows the live library first; timeline and search stay one tap away.")
            }

            Section {
                MemoryLibraryFilterBar(
                    selectedArtifactKind: $selectedArtifactKind,
                    selectedPipelineStage: $selectedPipelineStage,
                    selectedContext: $selectedContext,
                    selectedInsight: $selectedInsight,
                    snapshot: snapshot,
                    onClear: clearFilters
                )
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                Section {
                    Text("Showing \(snapshot.filteredCount) of \(snapshot.totalCount) memories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if snapshot.groups.isEmpty {
                    Section {
                        ContentUnavailableView(
                            filter.isActive ? "No matching memories" : "No Memories Yet",
                            systemImage: filter.isActive ? "line.3.horizontal.decrease.circle" : "square.stack",
                            description: Text(filter.isActive ? "Clear filters or try a broader view." : "Capture a thought from the toolbar to start the library.")
                        )
                    }
                } else {
                    ForEach(snapshot.groups) { group in
                        Section(group.dayLabel) {
                            ForEach(group.rows) { row in
                                NavigationLink {
                                    MemoryDetailView(recordID: row.memory.id)
                                } label: {
                                    MemoryLibraryRowView(row: row)
                                }
                            }
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
        .navigationTitle("tab.memories")
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .onChange(of: selectedArtifactKind) { _, _ in Task { await load() } }
        .onChange(of: selectedPipelineStage) { _, _ in Task { await load() } }
        .onChange(of: selectedContext) { _, _ in Task { await load() } }
        .onChange(of: selectedInsight) { _, _ in Task { await load() } }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchMemoryLibrary(filter: filter, limit: nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearFilters() {
        selectedArtifactKind = nil
        selectedPipelineStage = nil
        selectedContext = .any
        selectedInsight = .any
    }
}

private struct MemoryLibraryFilterBar: View {
    @Binding var selectedArtifactKind: ArtifactKind?
    @Binding var selectedPipelineStage: MemoryPipelineStage?
    @Binding var selectedContext: MemoryLibraryContextFilter
    @Binding var selectedInsight: MemoryLibraryInsightFilter

    let snapshot: MemoryLibrarySnapshot?
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Filters")
                    .font(.headline)
                Spacer()
                Button("Clear", action: onClear)
                    .disabled(!isActive)
            }

            HStack {
                Menu(artifactTitle) {
                    Button("Any artifact") { selectedArtifactKind = nil }
                    ForEach(ArtifactKind.allCases) { kind in
                        Button(kind.rawValue.capitalized) {
                            selectedArtifactKind = kind
                        }
                    }
                }

                Menu(stageTitle) {
                    Button("Any status") { selectedPipelineStage = nil }
                    ForEach(MemoryPipelineStage.allCases) { stage in
                        Button(stage.rawValue.capitalized) {
                            selectedPipelineStage = stage
                        }
                    }
                }
            }

            HStack {
                Menu(contextTitle) {
                    ForEach(MemoryLibraryContextFilter.allCases) { filter in
                        Button(contextLabel(filter)) {
                            selectedContext = filter
                        }
                    }
                }

                Menu(insightTitle) {
                    ForEach(MemoryLibraryInsightFilter.allCases) { filter in
                        Button(insightLabel(filter)) {
                            selectedInsight = filter
                        }
                    }
                }
            }

            if let metadata = snapshot?.metadata {
                Text("Available: \(metadata.availableArtifactKinds.map(\.rawValue).joined(separator: ", ").ifEmpty("none"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
    }

    private var isActive: Bool {
        selectedArtifactKind != nil || selectedPipelineStage != nil || selectedContext != .any || selectedInsight != .any
    }

    private var artifactTitle: String {
        selectedArtifactKind?.rawValue.capitalized ?? "Any artifact"
    }

    private var stageTitle: String {
        selectedPipelineStage?.rawValue.capitalized ?? "Any status"
    }

    private var contextTitle: String {
        contextLabel(selectedContext)
    }

    private var insightTitle: String {
        insightLabel(selectedInsight)
    }

    private func contextLabel(_ filter: MemoryLibraryContextFilter) -> String {
        switch filter {
        case .any: return "Any context"
        case .hasLocation: return "Has location"
        case .hasWeather: return "Has weather"
        case .hasMusic: return "Has music"
        }
    }

    private func insightLabel(_ filter: MemoryLibraryInsightFilter) -> String {
        switch filter {
        case .any: return "Any insight"
        case .hasStoryline: return "Has storyline"
        case .hasReflection: return "Has reflection"
        case .hasEntities: return "Has entities"
        }
    }
}

private struct MemoryLibraryRowView: View {
    let row: MemoryLibraryRowSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.memory.title)
                .font(.headline)
                .lineLimit(2)

            Text(row.memory.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(row.memory.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if let status = row.memory.pipelineStatus {
                    Text(status.userLabel)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(row.artifactKinds, id: \.self) { kind in
                    Label(kind.rawValue.capitalized, systemImage: icon(for: kind))
                        .font(.caption2)
                }
                if row.hasInsights {
                    Label("\(row.relatedStorylineCount + row.relatedReflectionCount + row.entityCount)", systemImage: "sparkles")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func icon(for kind: ArtifactKind) -> String {
        switch kind {
        case .text: return "doc.text"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .link: return "link"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .todo: return "checklist"
        case .document: return "doc"
        }
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

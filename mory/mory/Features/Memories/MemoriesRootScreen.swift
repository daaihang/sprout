import SwiftUI

struct MemoriesRootScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var selectedArtifactKind: ArtifactKind?
    @State private var selectedPipelineStage: MemoryPipelineStage?
    @State private var selectedContext: MemoryLibraryContextFilter = .any
    @State private var selectedInsight: MemoryLibraryInsightFilter = .any
    @State private var snapshot: MemoryLibrarySnapshot?
    @State private var isPresentingComposer = false
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
                Text("memories.library.footer")
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
                    Text("memories.library.count \(snapshot.filteredCount) \(snapshot.totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if snapshot.groups.isEmpty {
                    Section {
                        MoryPublicEmptyStateView(
                            state: filter.isActive ? .filteredMemories : .memories,
                            onAction: handleEmptyStateAction
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
                                .accessibilityElement(children: .combine)
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
        .sheet(isPresented: $isPresentingComposer) {
            CaptureComposerView {
                Task { await load() }
            }
        }
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

    private func handleEmptyStateAction() {
        if filter.isActive {
            clearFilters()
        } else {
            isPresentingComposer = true
        }
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
                Text("memories.filters.title")
                    .font(.headline)
                Spacer()
                Button("memories.filters.clear", action: onClear)
                    .disabled(!isActive)
            }

            HStack {
                Menu(artifactTitle) {
                    Button("memories.filters.anyArtifact") { selectedArtifactKind = nil }
                    ForEach(ArtifactKind.allCases) { kind in
                        Button(artifactLabel(kind)) {
                            selectedArtifactKind = kind
                        }
                    }
                }

                Menu(stageTitle) {
                    Button("memories.filters.anyStatus") { selectedPipelineStage = nil }
                    ForEach(MemoryPipelineStage.allCases) { stage in
                        Button(stageLabel(stage)) {
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
                Text("memories.filters.available \(metadata.availableArtifactKinds.map(artifactLabel).joined(separator: ", ").ifEmpty(String(localized: "common.none")))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
    }

    private var isActive: Bool {
        selectedArtifactKind != nil || selectedPipelineStage != nil || selectedContext != .any || selectedInsight != .any
    }

    private var artifactTitle: String {
        selectedArtifactKind.map(artifactLabel) ?? String(localized: "memories.filters.anyArtifact")
    }

    private var stageTitle: String {
        selectedPipelineStage.map(stageLabel) ?? String(localized: "memories.filters.anyStatus")
    }

    private var contextTitle: String {
        contextLabel(selectedContext)
    }

    private var insightTitle: String {
        insightLabel(selectedInsight)
    }

    private func contextLabel(_ filter: MemoryLibraryContextFilter) -> String {
        switch filter {
        case .any: return String(localized: "memories.filters.anyContext")
        case .hasLocation: return String(localized: "memories.filters.hasLocation")
        case .hasWeather: return String(localized: "memories.filters.hasWeather")
        case .hasMusic: return String(localized: "memories.filters.hasMusic")
        }
    }

    private func insightLabel(_ filter: MemoryLibraryInsightFilter) -> String {
        switch filter {
        case .any: return String(localized: "memories.filters.anyInsight")
        case .hasStoryline: return String(localized: "memories.filters.hasStoryline")
        case .hasReflection: return String(localized: "memories.filters.hasReflection")
        case .hasEntities: return String(localized: "memories.filters.hasEntities")
        }
    }

    private func artifactLabel(_ kind: ArtifactKind) -> String {
        switch kind {
        case .text: return String(localized: "capture.type.text")
        case .photo: return String(localized: "capture.type.photo")
        case .audio: return String(localized: "capture.type.audio")
        case .music: return String(localized: "capture.type.music")
        case .link: return String(localized: "capture.type.link")
        case .location: return String(localized: "capture.type.location")
        case .weather: return String(localized: "capture.type.weather")
        case .todo: return String(localized: "capture.type.todo")
        case .document: return String(localized: "capture.type.document")
        }
    }

    private func stageLabel(_ stage: MemoryPipelineStage) -> String {
        switch stage {
        case .pending: return String(localized: "pipeline.status.pending")
        case .running: return String(localized: "pipeline.status.running")
        case .completed: return String(localized: "pipeline.status.completed")
        case .failed: return String(localized: "pipeline.status.failed")
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
                    Label(kind.presentationLabel, systemImage: icon(for: kind))
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
        .accessibilityElement(children: .combine)
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

private extension ArtifactKind {
    var presentationLabel: String {
        switch self {
        case .text: return String(localized: "capture.type.text")
        case .photo: return String(localized: "capture.type.photo")
        case .audio: return String(localized: "capture.type.audio")
        case .music: return String(localized: "capture.type.music")
        case .link: return String(localized: "capture.type.link")
        case .location: return String(localized: "capture.type.location")
        case .weather: return String(localized: "capture.type.weather")
        case .todo: return String(localized: "capture.type.todo")
        case .document: return String(localized: "capture.type.document")
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

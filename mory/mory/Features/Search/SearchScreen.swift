import SwiftUI

struct SearchScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var query = ""
    @State private var result = SearchSnapshot(query: "", memories: [], entities: [], arcs: [], reflections: [])
    @State private var errorMessage: String?
    @State private var indexStatusMessage: String?
    @State private var isRebuildingIndex = false
    @State private var isSearchPresented = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if query.trimmedOrNil == nil {
                Section("Semantic index") {
                    if let indexStatusMessage {
                        Text(verbatim: indexStatusMessage)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: "Core Spotlight indexing is available when V6 semantic search is enabled.")
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await rebuildIndex() }
                    } label: {
                        if isRebuildingIndex {
                            ProgressView()
                        } else {
                            Text(verbatim: "Rebuild search index")
                        }
                    }
                    .disabled(isRebuildingIndex)
                }

                Section("search.section.search") {
                    Text("search.hint")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                if result.isPubliclyEmpty {
                    Section {
                        MoryPublicEmptyStateView(
                            state: .search,
                            onAction: { query = "" }
                        )
                    }
                }

                Section("Search source") {
                    Text(verbatim: result.sourceSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("search.section.memories") {
                    if result.memories.isEmpty {
                        Text("search.empty.memories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.memories) { memoryResult in
                            NavigationLink {
                                MemoryDetailView(recordID: memoryResult.memory.record.id)
                            } label: {
                                SearchMemoryRow(result: memoryResult)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section("search.section.entities") {
                    if result.entities.isEmpty {
                        Text("search.empty.entities")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.entities) { entityResult in
                            NavigationLink {
                                EntityDestinationView(entityID: entityResult.entity.id, kind: entityResult.entity.kind)
                            } label: {
                                SearchEntityRow(result: entityResult)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section("search.section.arcs") {
                    if result.arcs.isEmpty {
                        Text("search.empty.arcs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.arcs) { arcResult in
                            NavigationLink {
                                ArcDetailView(arcID: arcResult.summary.arc.id)
                            } label: {
                                SearchArcRow(result: arcResult)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                Section("search.section.reflections") {
                    if result.reflections.isEmpty {
                        Text("search.empty.reflections")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.reflections) { reflectionResult in
                            NavigationLink {
                                ReflectionDetailView(reflectionID: reflectionResult.summary.reflection.id)
                            } label: {
                                SearchReflectionRow(result: reflectionResult)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .navigationTitle("search.nav.title")
        .searchable(text: $query, isPresented: $isSearchPresented, prompt: "search.prompt")
        .searchFocused($isSearchFocused)
        .onAppear {
            DispatchQueue.main.async {
                isSearchPresented = true
                isSearchFocused = true
            }
        }
        .task(id: query) {
            await load()
        }
    }

    private func load() async {
        do {
            result = try await memoryRepository.searchSemanticFirst(query: query, limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildIndex() async {
        isRebuildingIndex = true
        defer { isRebuildingIndex = false }

        do {
            let report = try await memoryRepository.rebuildSpotlightIndex()
            if let skippedReason = report.skippedReason {
                indexStatusMessage = skippedReason
            } else {
                indexStatusMessage = "Indexed \(report.indexedItemCount) memories."
            }
        } catch {
            indexStatusMessage = error.localizedDescription
        }
    }
}

private struct SearchMemoryRow: View {
    let result: SearchMemoryResultSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.small) {
            Text(result.memory.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(result.memory.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !result.explanations.isEmpty {
                Text(result.explanations.prefix(3).map { "\($0.source.rawValue): \($0.label)" }.joined(separator: " | "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SearchEntityRow: View {
    let result: SearchEntityResultSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.small) {
            Text(result.entity.displayName)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(result.entity.summary.ifEmpty(String(localized: "common.noSummary")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("search.entity.stats \(result.relatedMemoryCount) \(result.artifactCount) \(result.arcCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !result.relatedThemes.isEmpty {
                Text(result.relatedThemes.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !result.relatedPeople.isEmpty {
                Text(result.relatedPeople.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SearchArcRow: View {
    let result: SearchArcResultSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.small) {
            Text(result.summary.arc.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(result.summary.arc.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !result.summary.relatedMemories.isEmpty {
                Text(result.summary.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SearchReflectionRow: View {
    let result: SearchReflectionResultSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: MorySpacing.small) {
            Text(result.summary.reflection.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(result.summary.reflection.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if !result.summary.relatedMemories.isEmpty {
                Text(result.summary.relatedMemories.map(\.title).joined(separator: " | "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension SearchSnapshot {
    var isPubliclyEmpty: Bool {
        memories.isEmpty && entities.isEmpty && arcs.isEmpty && reflections.isEmpty
    }

    var sourceSummary: String {
        switch semanticSearchStatus {
        case .notRequested:
            return retrievalSources.isEmpty ? "Exact local search" : retrievalSources.map(\.rawValue).joined(separator: " + ")
        case .disabled:
            return "Semantic search disabled; using exact local fallback."
        case .unavailable:
            return "Core Spotlight unavailable; using exact local fallback."
        case let .succeeded(resultCount):
            return resultCount > 0 ? "Core Spotlight + local fallback" : "Core Spotlight returned no matches; using local fallback."
        case let .failed(message):
            return "Core Spotlight failed: \(message). Using local fallback."
        }
    }
}

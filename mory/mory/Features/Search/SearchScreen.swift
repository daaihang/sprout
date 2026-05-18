import SwiftUI

struct SearchScreen: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var query = ""
    @State private var result = SearchSnapshot(query: "", memories: [], entities: [], arcs: [], reflections: [])
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if query.trimmedOrNil == nil {
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
        .searchable(text: $query, prompt: "search.prompt")
        .task(id: query) {
            await load()
        }
    }

    private func load() async {
        do {
            result = try memoryRepository.search(query: query, limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
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
        }
        .moryCard(tone: .memory)
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
        .moryCard(tone: .entity)
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
        .moryCard(tone: .storyline)
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
        .moryCard(tone: .reflection)
    }
}

private extension SearchSnapshot {
    var isPubliclyEmpty: Bool {
        memories.isEmpty && entities.isEmpty && arcs.isEmpty && reflections.isEmpty
    }
}

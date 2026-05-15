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
                }
            } else {
                Section("search.section.memories") {
                    if result.memories.isEmpty {
                        Text("search.empty.memories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.memories) { memoryResult in
                            NavigationLink {
                                MemoryDetailView(recordID: memoryResult.memory.record.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(memoryResult.memory.title)
                                        .font(.headline)
                                    Text(memoryResult.memory.summaryText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entityResult.entity.displayName)
                                        .font(.headline)
                                    Text(entityResult.entity.summary.ifEmpty(String(localized: "common.noSummary")))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("search.entity.stats \(entityResult.relatedMemoryCount) \(entityResult.artifactCount) \(entityResult.arcCount)")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    if !entityResult.relatedThemes.isEmpty {
                                        Text(entityResult.relatedThemes.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else if !entityResult.relatedPeople.isEmpty {
                                        Text(entityResult.relatedPeople.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(arcResult.summary.arc.title)
                                        .font(.headline)
                                    Text(arcResult.summary.arc.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    if !arcResult.summary.relatedMemories.isEmpty {
                                        Text(arcResult.summary.relatedMemories.map(\.title).joined(separator: " | "))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reflectionResult.summary.reflection.title)
                                        .font(.headline)
                                    Text(reflectionResult.summary.reflection.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                    if !reflectionResult.summary.relatedMemories.isEmpty {
                                        Text(reflectionResult.summary.relatedMemories.map(\.title).joined(separator: " | "))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            }
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

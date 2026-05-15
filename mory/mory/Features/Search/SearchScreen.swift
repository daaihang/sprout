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
                Section("Search") {
                    Text("Search memories, entities, arcs, and reflections from the same memory stack.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Memories") {
                    if result.memories.isEmpty {
                        Text("No memory matches.")
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

                Section("Entities") {
                    if result.entities.isEmpty {
                        Text("No entity matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.entities) { entityResult in
                            NavigationLink {
                                EntityDestinationView(entityID: entityResult.entity.id, kind: entityResult.entity.kind)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entityResult.entity.displayName)
                                        .font(.headline)
                                    Text(entityResult.entity.summary.ifEmpty("No summary"))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(entityResult.relatedMemoryCount) memories · \(entityResult.artifactCount) artifacts · \(entityResult.arcCount) arcs")
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

                Section("Arcs") {
                    if result.arcs.isEmpty {
                        Text("No arc matches.")
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

                Section("Reflections") {
                    if result.reflections.isEmpty {
                        Text("No reflection matches.")
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
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Search memories, people, arcs")
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

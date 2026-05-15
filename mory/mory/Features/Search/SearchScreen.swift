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
                        ForEach(result.memories) { memory in
                            NavigationLink {
                                MemoryDetailView(recordID: memory.record.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(memory.title)
                                        .font(.headline)
                                    Text(memory.summaryText)
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
                        ForEach(result.entities) { entity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entity.displayName)
                                    .font(.headline)
                                Text(entity.summary.ifEmpty("No summary"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Arcs") {
                    if result.arcs.isEmpty {
                        Text("No arc matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.arcs) { arc in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title)
                                    .font(.headline)
                                Text(arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                Section("Reflections") {
                    if result.reflections.isEmpty {
                        Text("No reflection matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.title)
                                    .font(.headline)
                                Text(reflection.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmedOrNil ?? fallback
    }
}

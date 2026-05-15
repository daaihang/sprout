import SwiftUI

struct EntityDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let entityID: UUID

    @State private var snapshot: EntityDetailSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                Section("entity.section.info") {
                    Text(snapshot.entity.displayName)
                        .font(.headline)
                    Text(snapshot.entity.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let summary = snapshot.entity.summary.trimmedOrNil {
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.relatedMemories") {
                    if snapshot.relatedMemories.isEmpty {
                        Text("common.empty.relatedMemories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.relatedMemories) { memory in
                            NavigationLink {
                                MemoryDetailView(recordID: memory.record.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
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

                Section("common.section.themes") {
                    if snapshot.relatedThemes.isEmpty {
                        Text("common.empty.themes")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.relatedThemes.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.people") {
                    if snapshot.relatedPeople.isEmpty {
                        Text("common.empty.people")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.relatedPeople.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.arcs") {
                    if snapshot.relatedArcs.isEmpty {
                        Text("common.empty.arcs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.relatedArcs) { arc in
                            NavigationLink {
                                ArcDetailView(arcID: arc.arc.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(arc.arc.title)
                                        .font(.headline)
                                    Text(arc.arc.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section("common.section.reflections") {
                    if snapshot.relatedReflections.isEmpty {
                        Text("common.empty.reflections")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.relatedReflections) { reflection in
                            NavigationLink {
                                ReflectionDetailView(reflectionID: reflection.reflection.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reflection.reflection.title)
                                        .font(.headline)
                                    Text(reflection.reflection.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("entity.nav.title")
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchEntityDetail(entityID: entityID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

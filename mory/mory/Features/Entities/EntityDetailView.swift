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
                Section("Entity") {
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

                Section("Related Memories") {
                    if snapshot.relatedMemories.isEmpty {
                        Text("No related memories yet.")
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

                Section("Themes") {
                    if snapshot.relatedThemes.isEmpty {
                        Text("No related themes yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.relatedThemes.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("People") {
                    if snapshot.relatedPeople.isEmpty {
                        Text("No related people yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.relatedPeople.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Arcs") {
                    if snapshot.relatedArcs.isEmpty {
                        Text("No linked arcs yet.")
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

                Section("Reflections") {
                    if snapshot.relatedReflections.isEmpty {
                        Text("No linked reflections yet.")
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
        .navigationTitle("Entity Detail")
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

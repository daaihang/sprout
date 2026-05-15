import SwiftUI

struct PersonDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let entityID: UUID

    @State private var snapshot: PersonDetailSnapshot?
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
                Section("Person") {
                    Text(snapshot.summary.entity.displayName)
                        .font(.headline)
                    if let summary = snapshot.summary.entity.summary.trimmedOrNil {
                        Text(summary)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(snapshot.summary.artifactCount) artifacts · \(snapshot.summary.reflectionCount) reflections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Related Memories") {
                    if snapshot.summary.relatedMemories.isEmpty {
                        Text("No related memories yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.summary.relatedMemories) { memory in
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
                    if snapshot.summary.themeLabels.isEmpty {
                        Text("No themes linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(snapshot.summary.themeLabels.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Arcs") {
                    if snapshot.relatedArcs.isEmpty {
                        Text("No arcs linked yet.")
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
                        Text("No reflections linked yet.")
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
        .navigationTitle("Person")
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchPersonDetail(entityID: entityID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

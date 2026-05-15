import SwiftUI

struct ArcDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let arcID: UUID

    @State private var snapshot: TemporalArcDetailSnapshot?
    @State private var errorMessage: String?
    @State private var isUpdating = false

    var body: some View {
        List {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let snapshot {
                Section("Arc") {
                    Text(snapshot.summary.arc.title)
                        .font(.headline)
                    Text(snapshot.summary.arc.summary)
                        .foregroundStyle(.secondary)
                    Text(snapshot.summary.arc.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.summary.arc.startDate.formatted(date: .abbreviated, time: .omitted)) - \(snapshot.summary.arc.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Actions") {
                    Button(isUpdating ? "Updating..." : "Accept Arc") {
                        Task { await acceptArc() }
                    }
                    .disabled(isUpdating)

                    Button(isUpdating ? "Updating..." : "Archive Arc") {
                        Task { await archiveArc() }
                    }
                    .disabled(isUpdating)
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

                Section("Entities") {
                    if snapshot.entityDetails.isEmpty {
                        Text("No linked entities yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.entityDetails) { entity in
                            NavigationLink {
                                PersonDetailView(entityID: entity.entity.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entity.entity.displayName)
                                        .font(.headline)
                                    Text(entity.entity.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Reflections") {
                    if snapshot.reflections.isEmpty {
                        Text("No reflections linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.reflections) { reflection in
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
        .navigationTitle("Arc Detail")
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchTemporalArcDetail(arcID: arcID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func acceptArc() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await memoryRepository.acceptTemporalArc(arcID: arcID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveArc() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await memoryRepository.archiveTemporalArc(arcID: arcID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

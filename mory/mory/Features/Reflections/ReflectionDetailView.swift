import SwiftUI

struct ReflectionDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let reflectionID: UUID

    @State private var snapshot: ReflectionDetailSnapshot?
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
                Section("reflection.section.info") {
                    Text(snapshot.summary.reflection.title)
                        .font(.headline)
                    Text(snapshot.summary.reflection.body)
                    Text(snapshot.summary.reflection.status.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(snapshot.summary.reflection.evidenceSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("reflection.section.actions") {
                    Button(isUpdating ? String(localized: "common.updating") : String(localized: "reflection.action.save")) {
                        Task { await saveReflection() }
                    }
                    .disabled(isUpdating)

                    Button(isUpdating ? String(localized: "common.updating") : String(localized: "reflection.action.dismiss")) {
                        Task { await dismissReflection() }
                    }
                    .disabled(isUpdating)

                    Button(isUpdating ? String(localized: "common.updating") : String(localized: "reflection.action.archive")) {
                        Task { await archiveReflection() }
                    }
                    .disabled(isUpdating)
                }

                Section("reflection.section.linkedArc") {
                    if let linkedArc = snapshot.linkedArc {
                        NavigationLink {
                            ArcDetailView(arcID: linkedArc.arc.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(linkedArc.arc.title)
                                    .font(.headline)
                                Text(linkedArc.arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    } else {
                        Text("reflection.empty.linkedArc")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("common.section.relatedMemories") {
                    if snapshot.summary.relatedMemories.isEmpty {
                        Text("common.empty.relatedMemories")
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

                Section("common.section.entities") {
                    if snapshot.entityDetails.isEmpty {
                        Text("common.empty.entities")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.entityDetails) { entity in
                            NavigationLink {
                                EntityDestinationView(entityID: entity.entity.id, kind: entity.entity.kind)
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
            }
        }
        .navigationTitle("reflection.nav.title")
        .task {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchReflectionDetail(reflectionID: reflectionID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveReflection() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await memoryRepository.saveReflection(reflectionID: reflectionID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func dismissReflection() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await memoryRepository.dismissReflection(reflectionID: reflectionID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func archiveReflection() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await memoryRepository.archiveReflection(reflectionID: reflectionID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

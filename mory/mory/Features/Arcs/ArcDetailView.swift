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
                Section("arc.section.info") {
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

                Section("arc.section.actions") {
                    Button(isUpdating ? String(localized: "common.updating") : String(localized: "arc.action.accept")) {
                        Task { await acceptArc() }
                    }
                    .disabled(isUpdating)

                    Button(isUpdating ? String(localized: "common.updating") : String(localized: "arc.action.archive")) {
                        Task { await archiveArc() }
                    }
                    .disabled(isUpdating)

                    if let mergeCandidate = snapshot.mergeCandidate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("arc.merge.candidate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(mergeCandidate.arc.title)
                                .font(.subheadline.weight(.medium))
                            if let overlapScore = snapshot.mergeCandidateOverlapScore {
                                Text("Overlap \(overlapScore.formatted(.number.precision(.fractionLength(2))))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button(isUpdating ? String(localized: "common.updating") : String(localized: "arc.action.merge")) {
                                Task { await mergeArc() }
                            }
                            .disabled(isUpdating)
                        }
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

                Section("common.section.reflections") {
                    if snapshot.reflections.isEmpty {
                        Text("common.empty.reflections")
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
        .navigationTitle("arc.nav.title")
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

    private func mergeArc() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            snapshot = try await memoryRepository.mergeTemporalArc(arcID: arcID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

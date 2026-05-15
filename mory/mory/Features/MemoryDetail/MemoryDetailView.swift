import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false

    var body: some View {
        List {
            if let snapshot {
                Section("Record") {
                    LabeledContent("Source", value: snapshot.record.captureSource.rawValue)
                    if let mood = snapshot.record.userMood {
                        LabeledContent("Mood", value: mood)
                    }
                    if let inputContext = snapshot.record.inputContext {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input Context")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(inputContext)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Raw Capture")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(snapshot.record.rawText)
                            .font(.body)
                    }
                    Text(snapshot.record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Artifacts") {
                    if snapshot.artifacts.isEmpty {
                        Text("No artifacts linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.artifacts) { artifact in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(artifact.title)
                                        .font(.headline)
                                    Spacer(minLength: 12)
                                    Text(artifact.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let summary = artifact.summary.trimmedOrNil {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let body = artifact.textContent.trimmedOrNil {
                                    Text(body)
                                        .font(.body)
                                        .lineLimit(6)
                                }

                                if let mediaRef = artifact.mediaRef {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Media")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("\(mediaRef.filename) • \(mediaRef.mimeType)")
                                            .font(.caption)
                                    }
                                }

                                if !artifact.metadata.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Metadata")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        ForEach(artifact.metadata.keys.sorted(), id: \.self) { key in
                                            if let value = artifact.metadata[key] {
                                                Text("\(key): \(value)")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Analysis") {
                    if let pipelineStatus = snapshot.pipelineStatus {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pipelineStatus.userLabel)
                                .font(.headline)
                            if let lastError = pipelineStatus.lastError?.trimmedOrNil {
                                Text(lastError)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if pipelineStatus.stage == .failed || pipelineStatus.stage == .pending {
                                Button(isRefreshingPipeline ? "Retrying..." : "Retry Analysis") {
                                    Task { await refreshPipeline() }
                                }
                                .disabled(isRefreshingPipeline)
                            }
                        }
                    }

                    if let analysis = snapshot.analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(analysis.summary)
                                .font(.body)
                            if !analysis.themes.isEmpty {
                                Text(analysis.themes.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !analysis.retrievalTerms.isEmpty {
                                Text(analysis.retrievalTerms.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("No analysis snapshot.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Entities") {
                    if snapshot.entities.isEmpty {
                        Text("No linked entities.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.entities) { entity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entity.displayName)
                                    .font(.headline)
                                Text(entity.kind.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let summary = entity.summary.trimmedOrNil {
                                    Text(summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Edges") {
                    if snapshot.edges.isEmpty {
                        Text("No graph edges.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.edges.prefix(6)) { edge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(edge.relationKind.rawValue)
                                    .font(.headline)
                                Text("\(edge.sourceRecordIDs.count) records · \(edge.sourceArtifactIDs.count) artifacts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Temporal Arcs") {
                    if snapshot.arcs.isEmpty {
                        Text("No temporal arcs linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.arcs) { arc in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title)
                                    .font(.headline)
                                Text(arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Reflections") {
                    if snapshot.reflections.isEmpty {
                        Text("No reflections linked yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.title)
                                    .font(.headline)
                                Text(reflection.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            } else {
                Section {
                    ProgressView()
                }
            }
        }
        .navigationTitle("Memory")
        .task(id: recordID) {
            await load()
        }
    }

    private func load() async {
        do {
            snapshot = try memoryRepository.fetchMemoryDetail(recordID: recordID)
            errorMessage = snapshot == nil ? "Memory not found." : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPipeline() async {
        guard !isRefreshingPipeline else { return }
        isRefreshingPipeline = true
        defer { isRefreshingPipeline = false }

        do {
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }
}

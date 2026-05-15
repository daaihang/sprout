import SwiftUI

struct DebugDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var fixture: DebugMemoryFixtureSnapshot?
    @State private var graphOverview = GraphOverviewSnapshot(entitySections: [], topEdges: [], people: [], themes: [])
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var errorMessage: String?
    @State private var isSeeding = false
    @State private var isRebuilding = false
    @State private var isReloading = false

    var body: some View {
        List {
            Section("Debug Actions") {
                Button(isSeeding ? "Seeding..." : "Seed End-to-End Fixture") {
                    Task { await seedFixture() }
                }
                .disabled(isSeeding)

                if let fixture {
                    Text("Fixture record: \(fixture.recordTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(isRebuilding ? "Rebuilding..." : "Rerun Analysis + Graph + Arc + Reflection") {
                        Task { await rebuildFixture(recordID: fixture.recordID) }
                    }
                    .disabled(isRebuilding)
                }
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let fixture {
                Section("Chain Status") {
                    DebugChainRow(title: "Record", isComplete: true, detail: fixture.chain.record.id.uuidString)
                    DebugChainRow(title: "Artifact", isComplete: !fixture.chain.artifacts.isEmpty, detail: "\(fixture.chain.artifacts.count) item(s)")
                    DebugChainRow(
                        title: "Analysis",
                        isComplete: fixture.chain.analysis != nil,
                        detail: fixture.chain.pipelineStatus?.userLabel ?? fixture.chain.analysis?.summary ?? "Missing"
                    )
                    DebugChainRow(title: "Graph", isComplete: !fixture.chain.entities.isEmpty && !fixture.chain.links.isEmpty, detail: "\(fixture.chain.entities.count) entities / \(fixture.chain.links.count) links")
                    DebugChainRow(title: "Arc", isComplete: !fixture.chain.arcs.isEmpty, detail: fixture.chain.arcs.first?.title ?? "Missing")
                    DebugChainRow(title: "Reflection", isComplete: !fixture.chain.reflections.isEmpty, detail: fixture.chain.reflections.first?.title ?? "Missing")
                }

                Section("Pipeline Diagnostics") {
                    if pipelineStatuses.isEmpty {
                        Text("No pipeline statuses recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pipelineStatuses) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.status.userLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let lastError = item.status.lastError?.trimmedOrNil {
                                    Text(lastError)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }

                Section("Analysis Inspector") {
                    if let analysis = fixture.chain.analysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(analysis.summary)
                                .font(.body)
                            Text(analysis.themes.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(analysis.retrievalTerms.joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No analysis snapshot.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Graph Diagnostics") {
                    if graphOverview.entitySections.isEmpty {
                        Text("No entities.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(graphOverview.entitySections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.kind.rawValue.capitalized)
                                    .font(.headline)
                                ForEach(section.entities.prefix(3)) { entity in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entity.displayName)
                                            .font(.subheadline)
                                        Text(entity.kind.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Edge Diagnostics") {
                    if graphOverview.topEdges.isEmpty {
                        Text("No graph edges.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(graphOverview.topEdges.prefix(5)) { edge in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(edge.relationKind.rawValue) · weight \(edge.weight.formatted(.number.precision(.fractionLength(2))))")
                                    .font(.headline)
                                Text("\(edge.sourceRecordIDs.count) records / \(edge.sourceArtifactIDs.count) artifacts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Arc Diagnostics") {
                    if fixture.chain.arcs.isEmpty {
                        Text("No arcs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fixture.chain.arcs) { arc in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(arc.title)
                                    .font(.headline)
                                Text(arc.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Reflection Diagnostics") {
                    if fixture.chain.reflections.isEmpty {
                        Text("No reflections.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fixture.chain.reflections) { reflection in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reflection.title)
                                    .font(.headline)
                                Text(reflection.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Section("Diagnostics") {
                    Text("Seed a fixture to inspect the full capture -> artifact -> analysis -> graph -> arc -> reflection path.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Diagnostics")
        .task {
            await autoRefresh()
        }
    }

    @MainActor
    private func autoRefresh() async {
        await refreshLatestFixture()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { break }
            await refreshLatestFixture()
        }
    }

    @MainActor
    private func refreshLatestFixture() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            let targetRecordID: UUID?
            if let fixtureRecordID = fixture?.recordID {
                targetRecordID = fixtureRecordID
            } else {
                targetRecordID = try memoryRepository.fetchRecentMemories(limit: 1).first?.record.id
            }
            if let targetRecordID {
                fixture = try memoryRepository.fetchDebugFixtureSnapshot(recordID: targetRecordID)
            }
            graphOverview = try memoryRepository.fetchGraphOverview(limitPerKind: 6, edgeLimit: 8)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func seedFixture() async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        do {
            fixture = try await DebugSeedService.seed(repository: memoryRepository)
            if let fixture {
                try await memoryRepository.refreshMemoryPipeline(recordID: fixture.recordID)
                self.fixture = try memoryRepository.fetchDebugFixtureSnapshot(recordID: fixture.recordID)
            }
            graphOverview = try memoryRepository.fetchGraphOverview(limitPerKind: 6, edgeLimit: 8)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildFixture(recordID: UUID) async {
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        do {
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            fixture = try memoryRepository.fetchDebugFixtureSnapshot(recordID: recordID)
            graphOverview = try memoryRepository.fetchGraphOverview(limitPerKind: 6, edgeLimit: 8)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DebugChainRow: View {
    let title: String
    let isComplete: Bool
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isComplete ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

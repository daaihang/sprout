import SwiftUI

struct DebugDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var targetType: DebugAnalysisTarget = .memory
    @State private var selectedTargetID: UUID?
    @State private var targetSummary: String = "Latest memory"
    @State private var diagnostics: DebugDiagnosticsSnapshot?
    @State private var recentTargets: [DebugTargetRow] = []
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var errorMessage: String?
    @State private var isSeeding = false
    @State private var isRebuilding = false
    @State private var isReloading = false

    var body: some View {
        List {
            Section("Target") {
                Picker("Target Type", selection: $targetType) {
                    ForEach(DebugAnalysisTarget.allCases) { item in
                        Text(item.rawValue.capitalized).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Target", selection: Binding(
                    get: { selectedTargetID?.uuidString ?? "__latest__" },
                    set: { value in
                        selectedTargetID = value == "__latest__" ? nil : UUID(uuidString: value)
                    }
                )) {
                    Text("Latest").tag("__latest__")
                    ForEach(recentTargets) { item in
                        Text(item.title).tag(item.id.uuidString)
                    }
                }

                Text(targetSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let target = diagnostics?.target {
                    Text("Current target: \(targetLabel(for: target))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Debug Actions") {
                Button(isReloading ? "Loading..." : "Refresh Diagnostics") {
                    Task { await refreshDiagnostics() }
                }
                .disabled(isReloading)

                Button(isRebuilding ? "Rebuilding..." : "Analysis Only") {
                    Task { await rebuild(mode: .analysisOnly) }
                }
                .disabled(isRebuilding)

                Button(isRebuilding ? "Rebuilding..." : "Graph + Arc + Reflection") {
                    Task { await rebuild(mode: .graphArcReflection) }
                }
                .disabled(isRebuilding)

                Button(isRebuilding ? "Replaying..." : "Reflection Replay") {
                    Task { await rebuild(mode: .reflectionReplay) }
                }
                .disabled(isRebuilding)

                Button(isSeeding ? "Seeding..." : "Seed One Fixture") {
                    Task { await seedFixtures(count: 1) }
                }
                .disabled(isSeeding)

                Button(isSeeding ? "Seeding..." : "Batch Seed 3 Fixtures") {
                    Task { await seedFixtures(count: 3) }
                }
                .disabled(isSeeding)

                Button("Clear Debug Fixtures", role: .destructive) {
                    Task { await clearFixtures() }
                }
                Text("Only records explicitly marked as debug fixtures will be deleted.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let diagnostics {
                Section("Chain Status") {
                    if let fixture = diagnostics.fixture {
                        DebugChainRow(title: "Record", isComplete: true, detail: fixture.recordTitle)
                        DebugChainRow(title: "Artifact", isComplete: !fixture.chain.artifacts.isEmpty, detail: "\(fixture.chain.artifacts.count) item(s)")
                        DebugChainRow(title: "Analysis", isComplete: fixture.chain.analysis != nil, detail: fixture.chain.pipelineStatus?.userLabel ?? "Missing")
                        DebugChainRow(title: "Graph", isComplete: !fixture.chain.entities.isEmpty && !fixture.chain.links.isEmpty, detail: "\(fixture.chain.entities.count) entities / \(fixture.chain.links.count) links")
                        DebugChainRow(title: "Arc", isComplete: !fixture.chain.arcs.isEmpty, detail: fixture.chain.arcs.first?.title ?? "Missing")
                        DebugChainRow(title: "Reflection", isComplete: !fixture.chain.reflections.isEmpty, detail: fixture.chain.reflections.first?.title ?? "Missing")
                    } else {
                        Text("No fixture chain for the selected target.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Analyze Payload") {
                    if let analyzePayload = diagnostics.analyzePayload {
                        PayloadInspector(title: "Analyze Request", content: analyzePayload.requestBody)
                        PayloadInspector(title: "Analyze Response", content: analyzePayload.responseBody.ifEmpty("No analysis snapshot available"))
                        if let lastError = analyzePayload.lastError?.trimmedOrNil {
                            Text(lastError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if let rawErrorBody = analyzePayload.rawErrorBody?.trimmedOrNil {
                            PayloadInspector(title: "Analyze Raw Error Body", content: rawErrorBody)
                        }
                    } else {
                        Text("No analysis payload for this target.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reflection Payload") {
                    if let reflectionPayload = diagnostics.reflectionPayload {
                        PayloadInspector(title: "Reflection Request", content: reflectionPayload.requestBody)
                        PayloadInspector(title: "Reflection Response", content: reflectionPayload.responseBody.ifEmpty("No replay response"))
                        if let lastError = reflectionPayload.lastError?.trimmedOrNil {
                            Text(lastError)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if let rawErrorBody = reflectionPayload.rawErrorBody?.trimmedOrNil {
                            PayloadInspector(title: "Reflection Raw Error Body", content: rawErrorBody)
                        }
                    } else {
                        Text("No reflection payload for this target.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pipeline Trace") {
                    if let pipelineTrace = diagnostics.pipelineTrace {
                        if let failedStage = pipelineTrace.failedStage?.trimmedOrNil {
                            Text("Failed Stage: \(failedStage)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        if let statusCode = pipelineTrace.statusCode {
                            Text("HTTP Status: \(statusCode)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let rawErrorBody = pipelineTrace.rawErrorBody?.trimmedOrNil {
                            PayloadInspector(title: "Pipeline Raw Error", content: rawErrorBody)
                        }
                    } else {
                        Text("No persisted pipeline trace yet.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Provenance") {
                    if diagnostics.provenance.isEmpty {
                        Text("No provenance data.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(diagnostics.provenance, id: \.entityID) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.entityID.uuidString)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("aliases \(item.aliasCount) · records \(item.provenanceRecordIDs.count) · artifacts \(item.linkedArtifactIDs.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !item.evidenceSummary.isEmpty {
                                    Text(item.evidenceSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Pipeline") {
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
            }
        }
        .navigationTitle("Diagnostics")
        .task {
            await autoRefresh()
        }
        .onChange(of: targetType) { _, _ in
            Task { await refreshDiagnostics() }
        }
        .onChange(of: selectedTargetID) { _, _ in
            Task { await refreshDiagnostics() }
        }
    }

    @MainActor
    private func autoRefresh() async {
        await refreshDiagnostics()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { break }
            await refreshDiagnostics()
        }
    }

    @MainActor
    private func refreshDiagnostics() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            let selected = try resolveSelectedTarget()
            selectedTargetID = selected.id
            targetSummary = selected.title
            diagnostics = try memoryRepository.fetchDebugDiagnostics(targetType: targetType, targetID: selectedTargetID)
            recentTargets = try fetchRecentTargets(for: targetType)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuild(mode: DebugRebuildMode) async {
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        do {
            try await memoryRepository.rerunDebugPipeline(targetType: targetType, targetID: selectedTargetID, mode: mode)
            await refreshDiagnostics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func seedFixtures(count: Int) async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        do {
            _ = try await memoryRepository.seedDebugFixtures(count: count)
            await refreshDiagnostics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearFixtures() async {
        do {
            try memoryRepository.clearDebugFixtures()
            selectedTargetID = nil
            await refreshDiagnostics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveSelectedTarget() throws -> DebugTargetRow {
        let rows = try fetchRecentTargets(for: targetType)
        if let selectedTargetID, let match = rows.first(where: { $0.id == selectedTargetID }) {
            return match
        }
        if let first = rows.first {
            return first
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func fetchRecentTargets(for targetType: DebugAnalysisTarget) throws -> [DebugTargetRow] {
        switch targetType {
        case .memory:
            return try memoryRepository.fetchRecentMemories(limit: 8).map {
                DebugTargetRow(id: $0.record.id, title: $0.title)
            }
        case .arc:
            return try memoryRepository.fetchTemporalArcSummaries(limit: 8).map {
                DebugTargetRow(id: $0.arc.id, title: $0.arc.title)
            }
        case .reflection:
            return try memoryRepository.fetchReflectionSummaries(limit: 8).map {
                DebugTargetRow(id: $0.reflection.id, title: $0.reflection.title)
            }
        }
    }

    private func targetLabel(for snapshot: DebugTargetSnapshot) -> String {
        switch snapshot.targetType {
        case .memory:
            return snapshot.memory?.title ?? "Memory"
        case .arc:
            return snapshot.arc?.arc.title ?? "Arc"
        case .reflection:
            return snapshot.reflection?.reflection.title ?? "Reflection"
        }
    }
}

private struct DebugTargetRow: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
}

private struct PayloadInspector: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                Text(verbatim: content)
                    .font(.caption.monospaced())
                    .lineLimit(nil)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(minHeight: 140, maxHeight: 280)
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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmedOrNil ?? fallback
    }
}

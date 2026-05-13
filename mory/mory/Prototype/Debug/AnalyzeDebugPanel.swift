import SwiftUI

struct AnalyzeDebugPanel: View {
    @Environment(PrototypeWorkspaceStore.self) private var workspace
    @Environment(PrototypeSelectionStore.self) private var selection
    @State private var output = "Select a record to analyze."
    @State private var isLoading = false

    private let requestBuilder = AnalyzeRequestBuilder()
    private let responseMapper = AnalyzeResponseMapper()
    private let reflectionBuilder = ReflectionBuilder()
    private let client = PrototypeAPIClient(config: .preview)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analyze Debug")
                .font(.title2.weight(.semibold))

            CreationPanelView()
            TemporalArcCandidatesPanelView()

            if let record = selectedRecord {
                HStack {
                    Text("Selected Record")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(record.captureSource.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(record.rawText)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                if !workspace.linkedArtifacts(for: record.id).isEmpty {
                    Text("Linked artifacts: \(workspace.linkedArtifacts(for: record.id).count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button(isLoading ? "Analyzing..." : "Analyze Selected Record") {
                    Task {
                        await analyze(record: record)
                    }
                }
                .disabled(isLoading)

                ScrollView {
                    Text(output)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView("Select a Record", systemImage: "waveform.and.magnifyingglass")
            }

            Spacer()
        }
        .padding(20)
    }

    @MainActor
    private func analyze(record: RecordShell) async {
        isLoading = true
        defer { isLoading = false }

        let artifacts = workspace.artifacts.filter { record.artifactIDs.contains($0.id) }
        let payload = requestBuilder.build(record: record, artifacts: artifacts)

        do {
            let response = try await client.analyzePreview(payload)
            let analysis = responseMapper.map(recordID: record.id, response: response)
            let reflection = reflectionBuilder.build(record: record, artifacts: artifacts, analysis: analysis)
            workspace.setAnalysis(analysis)
            workspace.setReflection(reflection, for: record.id)
            output = """
            Tags: \(analysis.tags.joined(separator: ", "))
            Emotion: \(analysis.emotionLabel)

            Insight:
            \(analysis.insight)

            Entities:
            \(analysis.entities.map(\.name).joined(separator: ", "))

            Follow-up:
            \(analysis.followUpQuestion ?? "-")
            """
        } catch {
            output = "Analyze failed: \(error.localizedDescription)"
        }
    }

    private var selectedRecord: RecordShell? {
        if case let .record(recordID) = selection.selectedEntity {
            return workspace.records.first(where: { $0.id == recordID })
        }
        return workspace.records.first
    }
}

import SwiftUI

struct DebugDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var fixture: DebugMemoryFixtureSnapshot?
    @State private var errorMessage: String?
    @State private var isSeeding = false

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
                    DebugChainRow(title: "Analysis", isComplete: fixture.chain.analysis != nil, detail: fixture.chain.analysis?.summary ?? "Missing")
                    DebugChainRow(title: "Graph", isComplete: !fixture.chain.entities.isEmpty && !fixture.chain.links.isEmpty, detail: "\(fixture.chain.entities.count) entities / \(fixture.chain.links.count) links")
                    DebugChainRow(title: "Arc", isComplete: !fixture.chain.arcs.isEmpty, detail: fixture.chain.arcs.first?.title ?? "Missing")
                    DebugChainRow(title: "Reflection", isComplete: !fixture.chain.reflections.isEmpty, detail: fixture.chain.reflections.first?.title ?? "Missing")
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
                    if fixture.chain.entities.isEmpty {
                        Text("No entities.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(fixture.chain.entities) { entity in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entity.displayName)
                                    .font(.headline)
                                Text(entity.kind.rawValue)
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
            await refreshLatestFixture()
        }
    }

    private func seedFixture() async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        do {
            fixture = try await DebugSeedService.seed(repository: memoryRepository)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshLatestFixture() async {
        do {
            let latest = try memoryRepository.fetchRecentMemories(limit: 1).first
            if let latest {
                fixture = try memoryRepository.fetchDebugFixtureSnapshot(recordID: latest.record.id)
            }
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

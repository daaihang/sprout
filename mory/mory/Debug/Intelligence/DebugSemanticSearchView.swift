import SwiftUI

struct DebugSemanticSearchView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var query = "work pressure"
    @State private var result: SearchSnapshot?
    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var message: String?
    @State private var isConfirmingDeleteIndex = false

    var body: some View {
        List {
            Section {
                TextField("Query", text: $query)
                    .textInputAutocapitalization(.never)
                Button("Run exact local search") {
                    runExactSearch()
                }
                .disabled(isWorking)

                Button("Run semantic-first search") {
                    Task { await runSemanticSearch() }
                }
                .disabled(isWorking)

                Button("Enable semantic search") {
                    enableSemanticSearch()
                }
                .disabled(isWorking || preferences == nil || flags == nil)

                DebugActionNotice(
                    .mutating,
                    message: "Enable, rebuild, and delete actions write preferences or mutate the Core Spotlight index."
                )

                Button("Enable semantic search + rebuild index") {
                    Task { await enableSemanticSearchAndRebuildIndex() }
                }
                .disabled(isWorking || preferences == nil || flags == nil)

                Button("Rebuild Core Spotlight index") {
                    Task { await rebuildIndex() }
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    isConfirmingDeleteIndex = true
                } label: {
                    Text("Delete Core Spotlight index")
                }
                .disabled(isWorking)

                if isWorking {
                    DebugCenterProgressRow(text: "Working on search/index")
                }
                if let message {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("Semantic search is local/system-backed through Core Spotlight. Request ID is not applicable unless this later routes through a cloud retrieval service.")
            }

            Section("Feature gates") {
                DebugCenterValueRow(title: "Preference semanticSearchEnabled", value: preferences?.semanticSearchEnabled == true ? "enabled" : "disabled")
                DebugCenterValueRow(title: "V6 semanticSearch", value: flags?.semanticSearch == true ? "enabled" : "disabled")
                if let preferences, let flags {
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.semanticSearchGate(preferences: preferences, flags: flags))
                }
                DebugCenterValueRow(title: "Cloud intelligence", value: flags?.cloudQuestionSuggestions == true ? "question cloud enabled" : "question cloud disabled")
            }

            if let result {
                Section("Search summary") {
                    DebugCenterValueRow(title: "Query", value: result.query)
                    DebugCenterValueRow(title: "Status", value: DebugCenterFormatting.semanticStatusText(result.semanticSearchStatus))
                    DebugCenterValueRow(title: "Sources", value: DebugCenterFormatting.searchSourceText(result.retrievalSources))
                    DebugCenterValueRow(title: "Semantic memory IDs", value: result.semanticMemoryIDs.isEmpty ? "none" : result.semanticMemoryIDs.map(\.uuidString).joined(separator: "\n"))
                    DebugCenterValueRow(title: "Memories/entities/arcs/reflections", value: "\(result.memories.count) / \(result.entities.count) / \(result.arcs.count) / \(result.reflections.count)")
                }

                Section("Memory results") {
                    if result.memories.isEmpty {
                        Text("No memory results")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.memories) { item in
                            DebugCenterPayloadBlock(
                                title: item.memory.title,
                                content: ([
                                    "id: \(item.memory.id.uuidString)",
                                    "why: \(item.explanations.isEmpty ? "no explanation" : item.explanations.map { "\($0.source.rawValue) / \($0.label): \($0.snippet)" }.joined(separator: "\n"))",
                                ]).joined(separator: "\n")
                            )
                        }
                    }
                }

                Section("Entity results") {
                    if result.entities.isEmpty {
                        Text("No entity results")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(result.entities) { item in
                            DebugCenterValueRow(title: item.entity.displayName, value: "\(item.entity.kind.rawValue) · \(item.entity.id.uuidString)")
                        }
                    }
                }

                Section("Arc/reflection results") {
                    ForEach(result.arcs) { item in
                        DebugCenterValueRow(title: "arc: \(item.summary.arc.title)", value: item.summary.arc.id.uuidString)
                    }
                    ForEach(result.reflections) { item in
                        DebugCenterValueRow(title: "reflection: \(item.summary.reflection.title)", value: item.summary.reflection.id.uuidString)
                    }
                    if result.arcs.isEmpty && result.reflections.isEmpty {
                        Text("No arc/reflection results")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Semantic Search")
        .task {
            refreshControls()
        }
        .confirmationDialog(
            "Delete Core Spotlight index?",
            isPresented: $isConfirmingDeleteIndex,
            titleVisibility: .visible
        ) {
            Button("Delete Core Spotlight index", role: .destructive) {
                Task { await deleteIndex() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("This removes the local system search index for Mory. Memories remain in local storage and can be reindexed later.")
        }
    }

    @MainActor
    private func refreshControls() {
        preferences = try? memoryRepository.fetchIntelligencePreferences()
        flags = try? memoryRepository.fetchV6FeatureFlags()
    }

    @MainActor
    private func enableSemanticSearch() {
        guard let preferences, let flags else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let enabled = V6DebugControls.semanticSearchEnabled(preferences: preferences, flags: flags)
            try memoryRepository.saveIntelligencePreferences(enabled.preferences)
            try memoryRepository.saveV6FeatureFlags(enabled.flags)
            message = "Enabled semantic search preference and V6 flag."
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func runExactSearch() {
        isWorking = true
        defer { isWorking = false }
        do {
            result = try memoryRepository.search(query: query, limit: 12)
            message = "Exact search completed."
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func runSemanticSearch() async {
        isWorking = true
        defer { isWorking = false }
        do {
            result = try await memoryRepository.searchSemanticFirst(query: query, limit: 12)
            message = "Semantic-first search completed."
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func enableSemanticSearchAndRebuildIndex() async {
        guard let preferences, let flags else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let enabled = V6DebugControls.semanticSearchEnabled(preferences: preferences, flags: flags)
            try memoryRepository.saveIntelligencePreferences(enabled.preferences)
            try memoryRepository.saveV6FeatureFlags(enabled.flags)
            let report = try await memoryRepository.rebuildSpotlightIndex()
            message = "Enabled semantic search. \(DebugCenterFormatting.spotlightReportText(report))"
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func rebuildIndex() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let report = try await memoryRepository.rebuildSpotlightIndex()
            message = DebugCenterFormatting.spotlightReportText(report)
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func deleteIndex() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let report = try await memoryRepository.deleteSpotlightIndex()
            message = DebugCenterFormatting.spotlightReportText(report)
            refreshControls()
        } catch {
            message = error.localizedDescription
        }
    }
}

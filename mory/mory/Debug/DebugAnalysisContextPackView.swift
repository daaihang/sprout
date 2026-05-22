import SwiftUI

struct DebugAnalysisContextPackView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var pack: AnalysisContextPack?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Build context pack for latest memory") {
                    Task { await buildLatestPack() }
                }
                .disabled(isWorking)

                if isWorking {
                    ProgressView("Building context pack")
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
                Text("Phase 1 builds a local context pack only. It is not attached to /api/analyze until the v7 cloud contract phase.")
            }

            if let pack {
                Section("Summary") {
                    DebugContextValueRow(title: "Pack ID", value: pack.packID.uuidString)
                    DebugContextValueRow(title: "Target record", value: pack.targetRecordID.uuidString)
                    DebugContextValueRow(title: "Built", value: pack.builtAt.formatted(.iso8601))
                    DebugContextValueRow(title: "Semantic status", value: pack.retrieval.semanticSearchStatus)
                    DebugContextValueRow(title: "Sources", value: pack.retrieval.retrievalSources.joined(separator: ", "))
                    DebugContextValueRow(title: "Candidates", value: "\(pack.retrieval.candidateMemoryCount)")
                    if let fallbackReason = pack.retrieval.fallbackReason {
                        DebugContextValueRow(title: "Fallback", value: fallbackReason)
                    }
                }

                Section("Self brief") {
                    if let selfBrief = pack.selfBrief {
                        DebugContextValueRow(title: "Self entity", value: selfBrief.selfEntityID.uuidString)
                        DebugContextValueRow(title: "Display name", value: selfBrief.displayName ?? "none")
                        DebugContextValueRow(title: "Aliases", value: selfBrief.aliases.joined(separator: ", "))
                        DebugContextValueRow(title: "Roles", value: selfBrief.roleLabels.joined(separator: ", "))
                        DebugContextValueRow(title: "Goals", value: selfBrief.goalTitles.joined(separator: ", "))
                        DebugContextValueRow(title: "Privacy", value: selfBrief.privacyMode.rawValue)
                    } else {
                        Text("No self brief")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Budget") {
                    DebugContextValueRow(title: "Profiles", value: "\(pack.budget.selectedProfiles)/\(pack.budget.limits.maxProfiles)")
                    DebugContextValueRow(title: "Memories", value: "\(pack.budget.selectedRelatedMemories)/\(pack.budget.limits.maxRelatedMemories)")
                    DebugContextValueRow(title: "Arcs", value: "\(pack.budget.selectedArcs)/\(pack.budget.limits.maxArcs)")
                    DebugContextValueRow(title: "Reflections", value: "\(pack.budget.selectedReflections)/\(pack.budget.limits.maxReflections)")
                    DebugContextValueRow(title: "Corrections", value: "\(pack.budget.selectedCorrections)/\(pack.budget.limits.maxCorrections)")
                    DebugContextValueRow(title: "Dropped by privacy", value: "\(pack.budget.droppedByPrivacy)")
                    DebugContextValueRow(title: "Dropped by budget", value: "\(pack.budget.droppedByBudget)")
                }

                Section("Related memories") {
                    if pack.relatedMemories.isEmpty {
                        Text("No related memories")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pack.relatedMemories) { memory in
                            DebugContextPayloadBlock(
                                title: memory.title,
                                content: [
                                    "id: \(memory.recordID.uuidString)",
                                    "score: \(memory.scoreBreakdown.total)",
                                    "why: \(memory.inclusionReasons.joined(separator: ", "))",
                                    "snippet: \(memory.snippet)"
                                ].joined(separator: "\n")
                            )
                        }
                    }
                }

                Section("Profiles") {
                    if pack.relatedProfiles.isEmpty {
                        Text("No related profiles")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pack.relatedProfiles) { profile in
                            DebugContextValueRow(
                                title: profile.displayName,
                                value: "\(profile.kind.rawValue) / mentions=\(profile.mentionCount) / \(profile.inclusionReason)"
                            )
                        }
                    }
                }

                Section("Privacy decisions") {
                    if pack.privacyDecisions.isEmpty {
                        Text("No privacy decisions")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pack.privacyDecisions) { decision in
                            DebugContextValueRow(
                                title: decision.action.rawValue,
                                value: "\(decision.sourceType) \(decision.sourceID?.uuidString ?? "none")\n\(decision.reason)"
                            )
                        }
                    }
                }

                Section("Payload preview") {
                    DebugContextPayloadBlock(title: "JSON", content: payloadPreview(pack))
                }
            }
        }
        .navigationTitle("Context Pack")
        .task {
            await buildLatestPack()
        }
    }

    @MainActor
    private func buildLatestPack() async {
        isWorking = true
        defer { isWorking = false }
        do {
            guard let latest = try memoryRepository.fetchRecentMemories(limit: 1).first else {
                pack = nil
                message = "No memories available."
                return
            }
            let builder = ContextPackBuilder(repository: memoryRepository)
            pack = try await builder.build(targetRecordID: latest.id)
            message = "Built context pack for \(latest.title)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func payloadPreview(_ pack: AnalysisContextPack) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(pack), let text = String(data: data, encoding: .utf8) else {
            return "Unable to encode context pack."
        }
        return text
    }
}

private struct DebugContextValueRow: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "none" : value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DebugContextPayloadBlock: View {
    var title: String
    var content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                Text(content)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

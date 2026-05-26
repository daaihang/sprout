import SwiftUI

struct DebugAnalysisContextPackView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    @State private var pack: AnalysisContextPack?
    @State private var requestPayload: AnalysisRequestPayload?
    @State private var responseEnvelope: AnalysisResponseEnvelope?
    @State private var mappedResult: AnalysisMappedResult?
    @State private var isWorking = false
    @State private var isSending = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Build context pack for latest memory") {
                    Task { await buildLatestPack() }
                }
                .disabled(isWorking)

                Button("Send Analysis for latest memory") {
                    Task { await sendAnalysis() }
                }
                .disabled(isWorking || isSending || requestPayload == nil)

                if isWorking {
                    ProgressView("Building context pack")
                }

                if isSending {
                    ProgressView("Sending Analysis")
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
                Text("Analysis is the production memory analysis path. This debug view inspects the context pack, request payload, response proposals, and mapper output used by that path.")
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
                    DebugContextPayloadBlock(title: "Context pack JSON", content: payloadPreview(pack))
                    if let requestPayload {
                        DebugContextPayloadBlock(title: "Analysis request JSON", content: payloadPreview(requestPayload))
                    }
                }

                if let responseEnvelope {
                    Section("Analysis response") {
                        DebugContextValueRow(title: "Quality", value: "\(responseEnvelope.quality.confidence)")
                        DebugContextValueRow(title: "Uncertainty", value: responseEnvelope.quality.uncertaintyReasons.joined(separator: ", "))
                        DebugContextValueRow(title: "Needs user check", value: responseEnvelope.quality.needsUserCheck.joined(separator: ", "))
                        DebugContextValueRow(title: "Affect proposals", value: "\(responseEnvelope.affectProposals.count)")
                        DebugContextValueRow(title: "Graph deltas", value: "\(responseEnvelope.graphDeltaProposals.count + responseEnvelope.profileUpdateProposals.count)")
                        DebugContextValueRow(title: "Reflection candidates", value: "\(responseEnvelope.reflectionCandidates.count)")
                        DebugContextValueRow(title: "Question candidates", value: "\(responseEnvelope.questionCandidates.count)")
                        DebugContextPayloadBlock(title: "Response JSON", content: payloadPreview(responseEnvelope))
                    }
                }

                if let mappedResult {
                    Section("Mapped local proposals") {
                        DebugContextValueRow(title: "Affect snapshots", value: "\(mappedResult.affectProposals.count)")
                        DebugContextValueRow(title: "Graph delta proposals", value: "\(mappedResult.graphDeltaProposals.count)")
                        DebugContextValueRow(title: "Reflection proposals", value: "\(mappedResult.reflectionProposals.count)")
                        DebugContextValueRow(title: "Question proposals", value: "\(mappedResult.questionProposals.count)")
                        DebugContextValueRow(title: "Merge/split questions", value: "\(mappedResult.mergeSplitQuestions.count)")
                    }
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
                requestPayload = nil
                responseEnvelope = nil
                mappedResult = nil
                message = "No memories available."
                return
            }
            let builder = ContextPackBuilder(repository: memoryRepository)
            let builtPack = try await builder.build(targetRecordID: latest.id)
            guard let detail = try memoryRepository.fetchMemoryDetail(recordID: latest.id) else {
                pack = builtPack
                requestPayload = nil
                responseEnvelope = nil
                mappedResult = nil
                message = "Built context pack, but latest memory detail was unavailable."
                return
            }
            let affectSnapshots = try memoryRepository.fetchAffectSnapshots(recordID: latest.id, limit: 4)
            let knownEntities = detail.entities.map {
                EntityReference(
                    id: $0.id,
                    kind: $0.kind,
                    name: $0.displayName,
                    aliases: $0.aliases,
                    confidence: $0.confidence
                )
            }
            pack = builtPack
            requestPayload = AnalysisRequestBuilder().build(
                record: detail.record,
                artifacts: detail.artifacts,
                knownEntities: knownEntities,
                contextPack: builtPack,
                affectSnapshots: affectSnapshots
            )
            responseEnvelope = nil
            mappedResult = nil
            message = "Built context pack for \(latest.title)."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func sendAnalysis() async {
        if requestPayload == nil {
            await buildLatestPack()
        }
        guard let payload = requestPayload else {
            message = "No Analysis request payload is available."
            return
        }
        isSending = true
        defer { isSending = false }
        do {
            let response = try await cloudIntelligenceService.analyzeMemory(payload)
            responseEnvelope = response
            let recordID = UUID(uuidString: payload.recordShell.id) ?? payload.contextPack.targetRecordIDUUID
            mappedResult = AnalysisResponseMapper().map(recordID: recordID, response: response)
            message = "Analysis returned \(response.affectProposals.count) affect proposal(s), \(response.reflectionCandidates.count) reflection candidate(s), and \(response.questionCandidates.count) question candidate(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func payloadPreview<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
            return "Unable to encode payload."
        }
        return text
    }
}

private extension AnalysisRequestPayload.ContextPackPayload {
    var targetRecordIDUUID: UUID {
        UUID(uuidString: targetRecordID) ?? UUID()
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

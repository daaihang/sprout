#if DEBUG
import SwiftUI

struct DebugCloudIntelligenceView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    @State private var rawTranscript = "今天和 Alex 聊了项目节奏 有点担心月底之前做不完 但也决定先把通知链路跑通"
    @State private var photoLabels = "desk, notebook, coffee"
    @State private var photoOCR = "Mory V6 debug plan"
    @State private var captionHint = "A working desk while planning the V6 intelligence loop."
    @State private var isRunning = false
    @State private var latestSummary: DebugCloudRunSummary?
    @State private var latestErrorTrace: MoryAPIClient.DebugErrorSnapshot?
    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?

    var body: some View {
        List {
            Section("Effective gates") {
                if let preferences, let flags {
                    DebugCenterValueRow(title: "Cloud intelligence", value: preferences.cloudIntelligenceEnabled ? "enabled" : "blocked: cloudIntelligenceEnabled=false")
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.voiceRefinementGate(preferences: preferences))
                    DebugCenterValueRow(title: "Question suggestions", value: preferences.cloudIntelligenceEnabled && flags.cloudQuestionSuggestions ? "enabled" : cloudGateReason(preferences.cloudIntelligenceEnabled, flags.cloudQuestionSuggestions, flagName: "v6.cloudQuestionSuggestions"))
                    DebugCenterValueRow(title: "Chapter suggestions", value: preferences.cloudIntelligenceEnabled && flags.cloudChapterSuggestions ? "enabled" : cloudGateReason(preferences.cloudIntelligenceEnabled, flags.cloudChapterSuggestions, flagName: "v6.cloudChapterSuggestions"))
                } else {
                    DebugCenterProgressRow(text: "Loading cloud gates")
                }
            }

            Section {
                TextField("Raw transcript", text: $rawTranscript, axis: .vertical)
                    .lineLimit(3...6)
                    .textInputAutocapitalization(.sentences)
                TextField("Photo labels", text: $photoLabels)
                    .textInputAutocapitalization(.never)
                TextField("Photo OCR", text: $photoOCR, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Caption hint", text: $captionHint, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Inputs")
            } footer: {
                Text("These requests call the same cloud intelligence client used by capture, daily questions, chapter suggestions, photo semantics, and notification intent generation.")
            }

            Section("Actions") {
                Button("Run transcript refine") {
                    Task { await runTranscriptRefine() }
                }
                .disabled(isRunning)

                Button("Run daily question suggest") {
                    Task { await runQuestionSuggest() }
                }
                .disabled(isRunning)

                Button("Run chapter/stage suggest") {
                    Task { await runChapterSuggest() }
                }
                .disabled(isRunning)

                Button("Run photo semantic placeholder") {
                    Task { await runPhotoSemanticAnalysis() }
                }
                .disabled(isRunning)

                Button("Run notification intent suggest") {
                    Task { await runNotificationIntentSuggest() }
                }
                .disabled(isRunning)

                Button("Run provider eval") {
                    Task { await runProviderEval() }
                }
                .disabled(isRunning)

                if isRunning {
                    DebugCenterProgressRow(text: "Running cloud intelligence request")
                }
            }

            if let latestSummary {
                Section("Last result") {
                    DebugCenterValueRow(title: "Status", value: latestSummary.succeeded ? "success" : "failed")
                    DebugCenterValueRow(title: "Operation", value: latestSummary.operation)
                    DebugCenterValueRow(title: "Request ID", value: latestSummary.requestID ?? "none")
                    DebugCenterValueRow(title: "Provider", value: latestSummary.provider ?? "none")
                    DebugCenterValueRow(title: "Model", value: latestSummary.model ?? "none")
                    DebugCenterValueRow(title: "Prompt version", value: latestSummary.promptVersion ?? "none")
                    DebugCenterValueRow(title: "Usage", value: "input=\(latestSummary.inputTokens.map(String.init) ?? "n/a"), output=\(latestSummary.outputTokens.map(String.init) ?? "n/a")")
                    DebugCenterPayloadBlock(title: "Result", content: latestSummary.result)
                    if let error = latestSummary.error {
                        DebugCenterPayloadBlock(title: "Error", content: error)
                    }
                }
            }

            if let latestErrorTrace {
                Section("Last transport trace") {
                    DebugCenterValueRow(title: "Request ID", value: latestErrorTrace.requestID ?? "none")
                    DebugCenterValueRow(title: "HTTP status", value: latestErrorTrace.statusCode.map(String.init) ?? "none")
                    DebugCenterValueRow(title: "Failed stage", value: latestErrorTrace.failedStage ?? "none")
                    DebugCenterPayloadBlock(title: "Description", content: latestErrorTrace.errorDescription)
                    if let responseBody = latestErrorTrace.responseBody?.trimmedOrNil {
                        DebugCenterPayloadBlock(title: "Response body", content: responseBody)
                    }
                    if let rawErrorBody = latestErrorTrace.rawErrorBody?.trimmedOrNil {
                        DebugCenterPayloadBlock(title: "Raw error body", content: rawErrorBody)
                    }
                }
            }
        }
        .navigationTitle("Cloud Intelligence")
        .toolbar {
            Button {
                if let latestSummary {
                    UIPasteboard.general.string = buildReport(latestSummary)
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(latestSummary == nil)
        }
        .task {
            refreshCloudGates()
        }
    }

    @MainActor
    private func refreshCloudGates() {
        preferences = try? memoryRepository.fetchIntelligencePreferences()
        flags = try? memoryRepository.fetchV6FeatureFlags()
    }

    @MainActor
    private func runTranscriptRefine() async {
        await run("transcript_refine") {
            let response = try await cloudIntelligenceService.refineTranscript(
                MoryAPIClient.TranscriptRefinementPayload(
                    locale: Locale.autoupdatingCurrent.identifier,
                    recordID: nil,
                    audioArtifactID: nil,
                    rawTranscript: rawTranscript,
                    style: "clean_spoken_memory",
                    allowTitle: true
                )
            )
            return await makeSummary(
                operation: "transcript_refine",
                meta: response.meta,
                lines: [
                    "suggested_title: \(response.suggestedTitle ?? "none")",
                    "refined_transcript: \(response.refinedTranscript)",
                    "edits: \(response.edits.map { "\($0.kind)=\($0.summary)" }.joined(separator: " | "))",
                ]
            )
        }
    }

    @MainActor
    private func runQuestionSuggest() async {
        await run("question_suggest") {
            let evidence = try evidenceSnippets(limit: 4)
            let targetID = evidence.first?.recordID ?? UUID().uuidString
            let response = try await cloudIntelligenceService.suggestQuestions(
                MoryAPIClient.QuestionSuggestionPayload(
                    locale: Locale.autoupdatingCurrent.identifier,
                    target: .init(type: "record", id: targetID, kind: "daily_reflection"),
                    evidence: evidence,
                    knownProfile: .init(displayName: "Alex", aliases: ["A"], relationshipToUser: "coworker"),
                    userPreferences: .init(allowSensitiveQuestions: false, questionTone: "quiet_specific")
                )
            )
            return await makeSummary(
                operation: "question_suggest",
                meta: response.meta,
                lines: response.questions.enumerated().map { index, question in
                    "\(index + 1). \(question.kind) · \(question.prompt) · confidence=\(question.confidence) · reason=\(question.reason)"
                }
            )
        }
    }

    @MainActor
    private func runChapterSuggest() async {
        await run("chapter_suggest") {
            let memories = try memoryRepository.fetchRecentMemories(limit: 8)
            let start = memories.map(\.record.updatedAt).min() ?? Date.now.addingTimeInterval(-7 * 24 * 60 * 60)
            let end = memories.map(\.record.updatedAt).max() ?? Date.now
            let response = try await cloudIntelligenceService.suggestChapters(
                MoryAPIClient.ChapterSuggestionPayload(
                    locale: Locale.autoupdatingCurrent.identifier,
                    timeWindow: .init(start: isoDate(start), end: isoDate(end)),
                    signals: [
                        .init(kind: "theme", label: "work pressure", recordCount: max(2, memories.count), salience: 0.72),
                        .init(kind: "relationship", label: "Alex", recordCount: 2, salience: 0.58),
                    ],
                    evidenceSnippets: try evidenceSnippets(limit: 8)
                )
            )
            return await makeSummary(
                operation: "chapter_suggest",
                meta: response.meta,
                lines: response.chapterCandidates.enumerated().map { index, candidate in
                    "\(index + 1). \(candidate.title) · confidence=\(candidate.confidence) · confirm=\(candidate.requiresConfirmation) · \(candidate.summary)"
                }
            )
        }
    }

    @MainActor
    private func runPhotoSemanticAnalysis() async {
        await run("photo_semantic_analysis") {
            let response = try await cloudIntelligenceService.analyzePhotoSemantics(
                MoryAPIClient.PhotoSemanticAnalysisPayload(
                    locale: Locale.autoupdatingCurrent.identifier,
                    recordID: nil,
                    photoArtifactID: nil,
                    localLabels: photoLabels.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
                    ocrText: photoOCR.trimmedOrNil,
                    captionHint: captionHint.trimmedOrNil,
                    metadata: ["debug": "true"]
                )
            )
            return await makeSummary(
                operation: "photo_semantic_analysis",
                meta: response.meta,
                lines: [
                    "suggested_title: \(response.suggestedTitle ?? "none")",
                    "semantic_summary: \(response.semanticSummary)",
                    "tags: \(response.tags.joined(separator: ", "))",
                    "objects: \(response.objects.joined(separator: ", "))",
                    "text_highlights: \(response.textHighlights.joined(separator: " | "))",
                    "safety: \(response.safety)",
                    "confidence: \(response.confidence)",
                ]
            )
        }
    }

    @MainActor
    private func runNotificationIntentSuggest() async {
        await run("notification_intent_suggest") {
            let question = MoryAPIClient.QuestionCandidateResponse(
                kind: "daily_reflection",
                prompt: "最近你反复提到项目节奏，要不要补一句最卡的点？",
                reason: "Debug evidence repeats a work planning theme.",
                candidateAnswers: ["补一句", "暂时不用"],
                confidence: 0.76,
                sensitivity: "normal"
            )
            let response = try await cloudIntelligenceService.suggestNotificationIntent(
                MoryAPIClient.NotificationIntentSuggestionPayload(
                    locale: Locale.autoupdatingCurrent.identifier,
                    timeZone: TimeZone.autoupdatingCurrent.identifier,
                    trigger: "debug_manual",
                    recentEvidence: try evidenceSnippets(limit: 4),
                    question: question,
                    preferences: .init(
                        maxPerDay: 3,
                        quietHoursStart: "22:00",
                        quietHoursEnd: "08:00",
                        richPreviewsEnabled: true
                    )
                )
            )
            return await makeSummary(
                operation: "notification_intent_suggest",
                meta: response.meta,
                lines: [
                    "kind: \(response.intent.kind)",
                    "privacy: \(response.intent.privacyLevel)",
                    "title: \(response.intent.title)",
                    "body: \(response.intent.body)",
                    "deep_link: \(response.intent.deepLink ?? "none")",
                    "scheduled_at: \(response.intent.scheduledAt ?? "none")",
                ]
            )
        }
    }

    @MainActor
    private func runProviderEval() async {
        await run("provider_eval") {
            let response = try await cloudIntelligenceService.runProviderEval()
            let fallbackRequestID = await fetchDebugRequestID()
            return DebugCloudRunSummary(
                operation: "provider_eval",
                requestID: response.requestID ?? fallbackRequestID,
                provider: response.cases.compactMap(\.provider).first,
                model: response.cases.compactMap(\.model).first,
                promptVersion: response.promptVersion,
                inputTokens: nil,
                outputTokens: nil,
                result: response.cases.map { item in
                    [
                        "\(item.operation): \(item.success ? "success" : "failed")",
                        item.provider.map { "provider=\($0)" },
                        item.model.map { "model=\($0)" },
                        item.errorClass.map { "error_class=\($0)" },
                        item.retryable.map { "retryable=\($0)" },
                        item.error.map { "error=\($0)" },
                    ]
                    .compactMap { $0 }
                    .joined(separator: " | ")
                }
                .joined(separator: "\n"),
                error: response.cases.contains(where: { !$0.success }) ? "One or more provider eval cases failed." : nil
            )
        }
    }

    @MainActor
    private func run(_ operation: String, task: () async throws -> DebugCloudRunSummary) async {
        guard !isRunning else { return }
        isRunning = true
        latestSummary = nil
        latestErrorTrace = nil
        defer { isRunning = false }

        do {
            latestSummary = try await task()
            latestErrorTrace = await fetchDebugError()
        } catch {
            let trace = await fetchDebugError()
            let traceRequestID = trace?.requestID
            let fallbackRequestID = await fetchDebugRequestID()
            latestErrorTrace = trace
            latestSummary = DebugCloudRunSummary(
                operation: operation,
                requestID: traceRequestID ?? fallbackRequestID,
                provider: nil,
                model: nil,
                promptVersion: nil,
                inputTokens: nil,
                outputTokens: nil,
                result: "No decoded result.",
                error: error.localizedDescription
            )
        }
    }

    private func makeSummary(
        operation: String,
        meta: MoryAPIClient.CloudIntelligenceMeta?,
        lines: [String]
    ) async -> DebugCloudRunSummary {
        let metaRequestID = meta?.requestID
        let fallbackRequestID = await fetchDebugRequestID()
        return DebugCloudRunSummary(
            operation: operation,
            requestID: metaRequestID ?? fallbackRequestID,
            provider: meta?.provider,
            model: meta?.model,
            promptVersion: meta?.promptVersion,
            inputTokens: meta?.usage?.inputTokens,
            outputTokens: meta?.usage?.outputTokens,
            result: lines.isEmpty ? "empty response" : lines.joined(separator: "\n"),
            error: nil
        )
    }

    @MainActor
    private func evidenceSnippets(limit: Int) throws -> [MoryAPIClient.EvidenceSnippetPayload] {
        let memories = try memoryRepository.fetchRecentMemories(limit: limit)
        if memories.isEmpty {
            return [
                MoryAPIClient.EvidenceSnippetPayload(
                    recordID: UUID().uuidString,
                    artifactID: nil,
                    snippet: rawTranscript,
                    createdAt: isoDate(.now)
                ),
            ]
        }
        return memories.map { memory in
            MoryAPIClient.EvidenceSnippetPayload(
                recordID: memory.id.uuidString,
                artifactID: memory.primaryArtifact?.id.uuidString,
                snippet: memory.summaryText.ifEmpty(memory.title),
                createdAt: isoDate(memory.record.updatedAt)
            )
        }
    }

    private func fetchDebugError() async -> MoryAPIClient.DebugErrorSnapshot? {
        guard let debugService = cloudIntelligenceService as? any CloudIntelligenceDebugging else { return nil }
        return await debugService.latestCloudDebugError()
    }

    private func fetchDebugRequestID() async -> String? {
        guard let debugService = cloudIntelligenceService as? any CloudIntelligenceDebugging else { return nil }
        return await debugService.latestCloudDebugRequestID()
    }

    private func buildReport(_ summary: DebugCloudRunSummary) -> String {
        ([summary.headline] + summary.metaLines + ["", summary.result]).joined(separator: "\n")
    }
}
#endif

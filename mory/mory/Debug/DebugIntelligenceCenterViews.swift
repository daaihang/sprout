import SwiftUI
import UIKit
import BackgroundTasks

struct DebugV6ControlsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Refresh V6 controls") {
                    refresh()
                }
                .disabled(isWorking)

                if isWorking {
                    DebugCenterProgressRow(text: "Saving V6 controls")
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
                Text("These controls are internal gates only. They do not request system permissions such as notifications.")
            }

            Section("Effective gate status") {
                if let preferences, let flags {
                    ForEach(V6DebugControls.gateDiagnostics(preferences: preferences, flags: flags)) { diagnostic in
                        DebugV6GateDiagnosticRow(diagnostic: diagnostic)
                    }
                } else {
                    DebugCenterProgressRow(text: "Loading V6 gates")
                }
            }

            Section("Bulk controls") {
                Button("Enable all V6 flags") {
                    enableAllFlags()
                }
                .disabled(flags == nil || isWorking)

                Button("Reset V6 flags to defaults") {
                    saveFlags(V6FeatureFlags.defaults, message: "Reset V6 flags to defaults.")
                }
                .disabled(isWorking)

                Button("Enable cloud-first strongest policy") {
                    enableCloudFirstStrongestPolicy()
                }
                .disabled(preferences == nil || isWorking)

                Button("Reset intelligence preferences to defaults") {
                    savePreferences(IntelligencePreferences.defaults, message: "Reset intelligence preferences to defaults.")
                }
                .disabled(isWorking)
            }

            Section {
                if preferences != nil {
                    Toggle("Local intelligence", isOn: preferenceBoolBinding(\.localIntelligenceEnabled))
                    Toggle("Cloud intelligence", isOn: preferenceBoolBinding(\.cloudIntelligenceEnabled))
                    Toggle("Voice refinement", isOn: preferenceBoolBinding(\.voiceRefinementEnabled))
                    Toggle("Semantic search", isOn: preferenceBoolBinding(\.semanticSearchEnabled))
                    Toggle("Home suggestions", isOn: preferenceBoolBinding(\.homeSuggestionsEnabled))
                    Toggle("Daily questions", isOn: preferenceBoolBinding(\.dailyQuestionsEnabled))

                    Picker("Question tone", selection: questionToneBinding) {
                        ForEach(DailyQuestionTone.allCases) { tone in
                            Text(debugControlLabel(tone.rawValue)).tag(tone)
                        }
                    }

                    Picker("Sensitive topic policy", selection: sensitiveTopicPolicyBinding) {
                        ForEach(SensitiveTopicPolicy.allCases) { policy in
                            Text(debugControlLabel(policy.rawValue)).tag(policy)
                        }
                    }
                } else {
                    DebugCenterProgressRow(text: "Loading preferences")
                }
            } header: {
                Text("Intelligence preferences")
            } footer: {
                if let preferences {
                    Text("Updated \(preferences.updatedAt.formatted(.iso8601))")
                }
            }

            Section {
                if flags != nil {
                    Toggle("intelligenceJobs", isOn: flagBoolBinding(\.intelligenceJobs))
                    Toggle("entityProfiles", isOn: flagBoolBinding(\.entityProfiles))
                    Toggle("clarificationQuestions", isOn: flagBoolBinding(\.clarificationQuestions))
                    Toggle("homeGrid", isOn: flagBoolBinding(\.homeGrid))
                    Toggle("semanticSearch", isOn: flagBoolBinding(\.semanticSearch))
                    Toggle("dailyQuestions", isOn: flagBoolBinding(\.dailyQuestions))
                    Toggle("localNotifications", isOn: flagBoolBinding(\.localNotifications))
                    Toggle("cloudQuestionSuggestions", isOn: flagBoolBinding(\.cloudQuestionSuggestions))
                    Toggle("cloudChapterSuggestions", isOn: flagBoolBinding(\.cloudChapterSuggestions))
                    Toggle("multimediaViews", isOn: flagBoolBinding(\.multimediaViews))
                    Toggle("analyzeV7DualRun", isOn: flagBoolBinding(\.analyzeV7DualRun))
                } else {
                    DebugCenterProgressRow(text: "Loading V6 flags")
                }
            } header: {
                Text("V6 feature flags")
            } footer: {
                if let flags {
                    Text("Updated \(flags.updatedAt.formatted(.iso8601))")
                }
            }
        }
        .navigationTitle("V6 Controls")
        .task {
            refresh()
        }
    }

    private var questionToneBinding: Binding<DailyQuestionTone> {
        Binding {
            preferences?.questionTone ?? .evidenceBased
        } set: { newValue in
            guard var updated = preferences else { return }
            updated.questionTone = newValue
            savePreferences(updated, message: "Saved question tone.")
        }
    }

    private var sensitiveTopicPolicyBinding: Binding<SensitiveTopicPolicy> {
        Binding {
            preferences?.sensitiveTopicPolicy ?? .askBeforeShowing
        } set: { newValue in
            guard var updated = preferences else { return }
            updated.sensitiveTopicPolicy = newValue
            savePreferences(updated, message: "Saved sensitive topic policy.")
        }
    }

    private func preferenceBoolBinding(_ keyPath: WritableKeyPath<IntelligencePreferences, Bool>) -> Binding<Bool> {
        Binding {
            preferences?[keyPath: keyPath] ?? false
        } set: { newValue in
            guard var updated = preferences else { return }
            updated[keyPath: keyPath] = newValue
            savePreferences(updated, message: "Saved intelligence preference.")
        }
    }

    private func flagBoolBinding(_ keyPath: WritableKeyPath<V6FeatureFlags, Bool>) -> Binding<Bool> {
        Binding {
            flags?[keyPath: keyPath] ?? false
        } set: { newValue in
            guard var updated = flags else { return }
            updated[keyPath: keyPath] = newValue
            saveFlags(updated, message: "Saved V6 feature flag.")
        }
    }

    @MainActor
    private func refresh() {
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
            flags = try memoryRepository.fetchV6FeatureFlags()
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func savePreferences(_ updatedPreferences: IntelligencePreferences, message: String) {
        isWorking = true
        defer { isWorking = false }
        do {
            var stamped = updatedPreferences
            stamped.updatedAt = .now
            try memoryRepository.saveIntelligencePreferences(stamped)
            preferences = try memoryRepository.fetchIntelligencePreferences()
            self.message = message
        } catch {
            self.message = error.localizedDescription
        }
    }

    @MainActor
    private func saveFlags(_ updatedFlags: V6FeatureFlags, message: String) {
        isWorking = true
        defer { isWorking = false }
        do {
            var stamped = updatedFlags
            stamped.updatedAt = .now
            try memoryRepository.saveV6FeatureFlags(stamped)
            flags = try memoryRepository.fetchV6FeatureFlags()
            self.message = message
        } catch {
            self.message = error.localizedDescription
        }
    }

    @MainActor
    private func enableAllFlags() {
        guard let flags else { return }
        saveFlags(
            V6DebugControls.allFlagsEnabled(from: flags),
            message: "Enabled all V6 flags."
        )
    }

    @MainActor
    private func enableCloudFirstStrongestPolicy() {
        guard let preferences else { return }
        savePreferences(
            V6DebugControls.cloudFirstStrongestPolicy(from: preferences),
            message: "Enabled cloud-first strongest policy."
        )
    }
}

private struct DebugV6GateDiagnosticRow: View {
    let diagnostic: V6GateDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    diagnostic.statusText,
                    systemImage: diagnostic.isEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(diagnostic.isEnabled ? .green : .orange)
                Spacer()
                Text(diagnostic.title)
                    .font(.caption.weight(.semibold))
            }
            if !diagnostic.isEnabled {
                Text(diagnostic.reasonText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 3)
    }
}

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

struct DebugJobQueueView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    @State private var snapshot: DebugJobQueueSnapshot?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var selectedJobKind: DebugEnqueueableJobKind = .dailyQuestion
    @State private var bgTaskResult: String?

    var body: some View {
        List {
            Section("Effective gates") {
                if let flags {
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.jobWorkerGate(flags: flags))
                } else {
                    DebugCenterProgressRow(text: "Loading job worker gate")
                }
            }

            Section {
                Button("Refresh queue state") {
                    refresh()
                }
                .disabled(isWorking)

                Button("Process due jobs now") {
                    Task { await processDueJobs() }
                }
                .disabled(isWorking)

                Button("Recover unfinished jobs") {
                    Task { await recoverJobs() }
                }
                .disabled(isWorking)

                Picker("New job kind", selection: $selectedJobKind) {
                    ForEach(DebugEnqueueableJobKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                Button("Enqueue selected debug job") {
                    enqueueSelectedJob()
                }
                .disabled(isWorking)

                Button("Retry failed jobs") {
                    retryFailedJobs()
                }
                .disabled(isWorking)

                if isWorking {
                    DebugCenterProgressRow(text: "Working on job queue")
                }
                if let resultMessage {
                    Text(resultMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("This page uses the same repository job stores and IntelligenceJobWorker used during launch recovery and background intelligence preparation.")
            }

            Section("Background Tasks") {
                Button("Schedule BGProcessingTask") {
                    submitBGTask(identifier: BackgroundTaskIdentifier.process, isProcessing: true)
                }
                Button("Schedule BGAppRefreshTask") {
                    submitBGTask(identifier: BackgroundTaskIdentifier.refresh, isProcessing: false)
                }
                if let bgTaskResult {
                    Text(bgTaskResult)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if let snapshot {
                Section("Summary") {
                    DebugCenterValueRow(title: "Generated", value: snapshot.generatedAt.formatted(.iso8601))
                    DebugCenterValueRow(title: "Total jobs", value: "\(snapshot.totalJobCount)")
                    DebugCenterValueRow(title: "Due pending jobs", value: "\(snapshot.duePendingJobCount)")
                    DebugCenterValueRow(title: "Running jobs", value: "\(snapshot.runningJobCount)")
                    DebugCenterValueRow(title: "Failed jobs", value: "\(snapshot.failedJobCount)")
                    DebugCenterValueRow(title: "Cloud required jobs", value: "\(snapshot.cloudRequiredJobCount)")
                    DebugCenterValueRow(title: "Notification intents", value: "\(snapshot.notificationIntents.count)")
                    DebugCenterValueRow(title: "Unapplied graph deltas", value: "\(snapshot.unappliedGraphDeltaCount)")
                }

                Section("Job status counts") {
                    ForEach(snapshot.jobStatusCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                }

                Section("Job kind counts") {
                    ForEach(snapshot.jobKindCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                }

                Section("Notification intent counts") {
                    ForEach(snapshot.notificationStatusCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                }

                Section("Recent jobs") {
                    if snapshot.jobs.isEmpty {
                        Text("No jobs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.jobs.prefix(20)) { job in
                            DebugJobRow(job: job)
                        }
                    }
                }

                Section("Recent notification intents") {
                    if snapshot.notificationIntents.isEmpty {
                        Text("No notification intents")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.notificationIntents.prefix(12)) { intent in
                            DebugNotificationIntentRow(intent: intent)
                        }
                    }
                }

                Section("Graph deltas") {
                    ForEach(snapshot.graphDeltaCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                    ForEach(snapshot.graphDeltas.prefix(8)) { delta in
                        DebugGraphDeltaRow(delta: delta)
                    }
                }
            }
        }
        .navigationTitle("Job Queue")
        .toolbar {
            Button {
                if let snapshot {
                    UIPasteboard.general.string = buildReport(snapshot)
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(snapshot == nil)
        }
        .task {
            refresh()
        }
    }

    @MainActor
    private func refresh() {
        do {
            let jobs = try memoryRepository.fetchIntelligenceJobs(status: nil, limit: nil)
                .sorted { $0.updatedAt > $1.updatedAt }
            let intents = try memoryRepository.fetchNotificationIntents(status: nil, limit: nil)
                .sorted { $0.createdAt > $1.createdAt }
            let deltas = try memoryRepository.fetchGraphDeltas(applied: nil, limit: nil)
                .sorted { $0.createdAt > $1.createdAt }
            flags = try memoryRepository.fetchV6FeatureFlags()
            snapshot = DebugJobQueueSnapshot(
                generatedAt: .now,
                jobs: jobs,
                notificationIntents: intents,
                graphDeltas: deltas
            )
            resultMessage = nil
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func processDueJobs() async {
        isWorking = true
        defer { isWorking = false }
        let report = await IntelligenceJobWorker().processDueJobs(
            repository: memoryRepository,
            cloudIntelligenceService: cloudIntelligenceService,
            now: .now
        )
        resultMessage = [
            "completed=\(report.completedJobIDs.count)",
            "failed=\(report.failedJobIDs.count)",
            "unsupported=\(report.unsupportedJobIDs.count)",
            "questions=\(report.preparedQuestionCount)",
            "scheduled_notifications=\(report.scheduledNotificationCount)",
        ].joined(separator: ", ")
        refresh()
    }

    @MainActor
    private func recoverJobs() async {
        isWorking = true
        defer { isWorking = false }
        let report = await AppIntelligenceRecoveryService().recoverAfterLaunch(
            repository: memoryRepository,
            cloudIntelligenceService: cloudIntelligenceService,
            now: .now
        )
        resultMessage = [
            "resumed=\(report.resumedRunningJobIDs.count)",
            "retried=\(report.retriedFailedJobIDs.count)",
            "abandoned=\(report.abandonedFailedJobIDs.count)",
            "worker_completed=\(report.workerReport.completedJobIDs.count)",
            "errors=\(report.errors.count)",
        ].joined(separator: ", ")
        refresh()
    }

    @MainActor
    private func enqueueSelectedJob() {
        do {
            let job = IntelligenceJob(
                kind: selectedJobKind.kind,
                targetType: selectedJobKind.targetType,
                targetID: UUID(),
                status: .pending,
                priority: selectedJobKind.defaultPriority,
                scheduledAt: .now,
                requiresCloudAI: selectedJobKind.requiresCloudAI
            )
            try memoryRepository.upsertIntelligenceJob(job)
            resultMessage = "Enqueued \(job.kind.rawValue) job \(job.id.uuidString)."
            refresh()
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func retryFailedJobs() {
        do {
            let failed = try memoryRepository.fetchIntelligenceJobs(status: .failed, limit: nil)
            for job in failed {
                var retry = job
                retry.status = .pending
                retry.startedAt = nil
                retry.completedAt = nil
                retry.scheduledAt = .now
                retry.updatedAt = .now
                try memoryRepository.upsertIntelligenceJob(retry)
            }
            resultMessage = "Retried \(failed.count) failed job(s)."
            refresh()
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func submitBGTask(identifier: String, isProcessing: Bool) {
        do {
            if isProcessing {
                let request = BGProcessingTaskRequest(identifier: identifier)
                request.requiresNetworkConnectivity = true
                request.earliestBeginDate = nil
                try BGTaskScheduler.shared.submit(request)
            } else {
                let request = BGAppRefreshTaskRequest(identifier: identifier)
                request.earliestBeginDate = nil
                try BGTaskScheduler.shared.submit(request)
            }
            bgTaskResult = "Submitted \(identifier)"
        } catch {
            bgTaskResult = "Submit failed: \(error.localizedDescription)"
        }
    }

    private func buildReport(_ snapshot: DebugJobQueueSnapshot) -> String {
        var lines = [
            "=== Mory Job Queue Debug ===",
            "Generated: \(snapshot.generatedAt.formatted(.iso8601))",
            "Total jobs: \(snapshot.totalJobCount)",
            "Due pending: \(snapshot.duePendingJobCount)",
            "Running: \(snapshot.runningJobCount)",
            "Failed: \(snapshot.failedJobCount)",
            "Cloud required: \(snapshot.cloudRequiredJobCount)",
            "Notification intents: \(snapshot.notificationIntents.count)",
            "Unapplied graph deltas: \(snapshot.unappliedGraphDeltaCount)",
            "",
            "[Jobs]",
        ]
        for job in snapshot.jobs.prefix(40) {
            lines.append("\(job.kind.rawValue) \(job.status.rawValue) \(job.id.uuidString) target=\(job.targetType.rawValue)/\(job.targetID.uuidString) attempts=\(job.attemptCount) error=\(job.lastError ?? "none")")
        }
        return lines.joined(separator: "\n")
    }
}

struct DebugSemanticSearchView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var query = "work pressure"
    @State private var result: SearchSnapshot?
    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var message: String?

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

                Button("Enable semantic search + rebuild index") {
                    Task { await enableSemanticSearchAndRebuildIndex() }
                }
                .disabled(isWorking || preferences == nil || flags == nil)

                Button("Rebuild Core Spotlight index") {
                    Task { await rebuildIndex() }
                }
                .disabled(isWorking)

                Button(role: .destructive) {
                    Task { await deleteIndex() }
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

struct DebugHomeBoardDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var snapshot: HomeBoardDebugSnapshot?
    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var limit = 12
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section("Effective gates") {
                if let preferences, let flags {
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.homeBoardGate(preferences: preferences, flags: flags))
                    DebugCenterValueRow(title: "Home suggestions", value: preferences.homeSuggestionsEnabled ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Home grid", value: flags.homeGrid ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Entity profiles", value: flags.entityProfiles ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Clarification questions", value: flags.clarificationQuestions ? "enabled" : "disabled")
                } else {
                    DebugCenterProgressRow(text: "Loading Home Board gates")
                }
            }

            Section {
                Stepper("Limit: \(limit)", value: $limit, in: 4...24)
                Button("Refresh Home Board debug snapshot") {
                    refresh()
                }
                .disabled(isWorking)

                Button("Add first suggestion to board") {
                    applyFirstSuggestion(.addToBoard)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                Button("Prefer more first suggestion") {
                    applyFirstSuggestion(.preferMore)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                Button("Prefer less first suggestion") {
                    applyFirstSuggestion(.preferLess)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                if isWorking {
                    DebugCenterProgressRow(text: "Loading Home Board debug state")
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
                Text("This page exposes the home memory desktop rule inputs, visible cards, user-controlled cards, suggestions, and preference actions before the formal UI polish pass.")
            }

            if let snapshot {
                Section("Rule inputs") {
                    DebugCenterValueRow(title: "Generated", value: snapshot.generatedAt.formatted(.iso8601))
                    DebugCenterValueRow(title: "Date", value: snapshot.date.formatted(.iso8601))
                    DebugCenterValueRow(title: "Limit", value: "\(snapshot.limit)")
                    DebugCenterValueRow(title: "Memories / today / 24h", value: "\(snapshot.input.memoryCount) / \(snapshot.input.todayMemoryCount) / \(snapshot.input.recent24HourMemoryCount)")
                    DebugCenterValueRow(title: "Context / high salience", value: "\(snapshot.input.contextMemoryCount) / \(snapshot.input.highSalienceMemoryCount)")
                    DebugCenterValueRow(title: "Graph links/entities/edges", value: "\(snapshot.input.graphLinkCount) / \(snapshot.input.entityCount) / \(snapshot.input.edgeCount)")
                    DebugCenterValueRow(title: "Accepted arcs active/total", value: "\(snapshot.input.activeAcceptedArcCount) / \(snapshot.input.acceptedArcCount)")
                    DebugCenterValueRow(title: "Reflections suggested/saved", value: "\(snapshot.input.suggestedReflectionCount) / \(snapshot.input.savedReflectionCount)")
                    DebugCenterValueRow(title: "Pipeline running/failed", value: "\(snapshot.input.runningPipelineCount) / \(snapshot.input.failedPipelineCount)")
                }

                Section("Preference counters") {
                    DebugCenterValueRow(title: "Total", value: "\(snapshot.preferences.totalCount)")
                    DebugCenterValueRow(title: "Pinned", value: "\(snapshot.preferences.pinnedCount)")
                    DebugCenterValueRow(title: "Hidden", value: "\(snapshot.preferences.hiddenCount)")
                    DebugCenterValueRow(title: "Dismissed", value: "\(snapshot.preferences.dismissedCount)")
                }

                Section("User board cards") {
                    if snapshot.board.userBoardItems.isEmpty {
                        Text("No user board cards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.board.userBoardItems) { item in
                            DebugHomeBoardItemDiagnosticsRow(item: item, onAction: apply)
                        }
                    }
                }

                Section("Suggestion cards") {
                    if snapshot.board.suggestionItems.isEmpty {
                        Text("No suggestion cards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.board.suggestionItems) { item in
                            DebugHomeBoardItemDiagnosticsRow(item: item, onAction: apply)
                        }
                    }
                }
            }
        }
        .navigationTitle("Home Board Debug")
        .toolbar {
            Button {
                if let snapshot {
                    UIPasteboard.general.string = buildReport(snapshot)
                    message = "Copied Home Board debug report."
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(snapshot == nil)
        }
        .task {
            refresh()
        }
    }

    @MainActor
    private func refresh() {
        isWorking = true
        defer { isWorking = false }
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
            flags = try memoryRepository.fetchV6FeatureFlags()
            snapshot = try memoryRepository.fetchHomeBoardDebugSnapshot(for: .now, limit: limit)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func applyFirstSuggestion(_ action: HomeBoardPreferenceAction) {
        guard let item = snapshot?.board.suggestionItems.first else { return }
        apply(item, action)
    }

    @MainActor
    private func apply(_ item: HomeBoardItemSnapshot, _ action: HomeBoardPreferenceAction) {
        do {
            try memoryRepository.updateHomeBoardItemPreference(item, action: action)
            message = "Applied \(debugActionLabel(action)) to \(item.compositionItem.itemKey)."
            snapshot = try memoryRepository.fetchHomeBoardDebugSnapshot(for: .now, limit: limit)
        } catch {
            message = error.localizedDescription
        }
    }

    private func buildReport(_ snapshot: HomeBoardDebugSnapshot) -> String {
        var lines = [
            "=== Mory Home Board Debug ===",
            "Generated: \(snapshot.generatedAt.formatted(.iso8601))",
            "Memories: \(snapshot.input.memoryCount)",
            "Graph: links=\(snapshot.input.graphLinkCount), entities=\(snapshot.input.entityCount), edges=\(snapshot.input.edgeCount)",
            "Preferences: total=\(snapshot.preferences.totalCount), pinned=\(snapshot.preferences.pinnedCount), hidden=\(snapshot.preferences.hiddenCount), dismissed=\(snapshot.preferences.dismissedCount)",
            "",
            "[Cards]",
        ]
        for item in snapshot.board.items {
            lines.append("\(item.layout.layer.rawValue) \(item.cardKind.rawValue) \(debugHomeBoardTitle(item))")
            lines.append("  key=\(item.compositionItem.itemKey)")
            lines.append("  target=\(item.compositionItem.targetType.rawValue)/\(item.compositionItem.targetID.uuidString)")
            lines.append("  span=\(item.layout.span.widthColumns)x\(item.layout.span.heightUnits) priority=\(item.priority)")
            lines.append("  reason=\(item.reason)")
            lines.append("  source_records=\(item.sourceRecordIDs.map(\.uuidString).joined(separator: ","))")
        }
        return lines.joined(separator: "\n")
    }
}

private enum DebugEnqueueableJobKind: String, CaseIterable, Identifiable {
    case dailyQuestion
    case semanticIndex
    case notificationIntent
    case chapterCandidate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyQuestion: "Daily question"
        case .semanticIndex: "Semantic index"
        case .notificationIntent: "Notification intent"
        case .chapterCandidate: "Chapter candidate"
        }
    }

    var kind: IntelligenceJobKind {
        switch self {
        case .dailyQuestion: .dailyQuestion
        case .semanticIndex: .semanticIndex
        case .notificationIntent: .notificationIntent
        case .chapterCandidate: .chapterCandidate
        }
    }

    var targetType: IntelligenceTargetType {
        switch self {
        case .dailyQuestion, .chapterCandidate:
            .board
        case .semanticIndex:
            .searchIndex
        case .notificationIntent:
            .notification
        }
    }

    var defaultPriority: Double {
        switch self {
        case .dailyQuestion: 0.74
        case .semanticIndex: 0.62
        case .notificationIntent: 0.58
        case .chapterCandidate: 0.68
        }
    }

    var requiresCloudAI: Bool {
        switch self {
        case .dailyQuestion, .chapterCandidate:
            true
        case .semanticIndex, .notificationIntent:
            false
        }
    }
}

private struct DebugJobRow: View {
    let job: IntelligenceJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(job.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(job.status == .failed ? .red : .secondary)
            }
            DebugCenterValueRow(title: "ID", value: job.id.uuidString)
            DebugCenterValueRow(title: "Target", value: "\(job.targetType.rawValue) · \(job.targetID.uuidString)")
            DebugCenterValueRow(title: "Priority / attempts", value: "\(job.priority) / \(job.attemptCount)")
            DebugCenterValueRow(title: "Cloud", value: DebugCenterFormatting.boolText(job.requiresCloudAI))
            DebugCenterValueRow(title: "Scheduled", value: job.scheduledAt.formatted(.iso8601))
            if let lastError = job.lastError?.trimmedOrNil {
                DebugCenterPayloadBlock(title: "Last error", content: lastError)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DebugNotificationIntentRow: View {
    let intent: NotificationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(intent.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(intent.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(intent.title)
                .font(.caption)
            Text(intent.body)
                .font(.caption)
                .foregroundStyle(.secondary)
            DebugCenterValueRow(title: "Target", value: "\(intent.targetType.rawValue) · \(intent.targetID.uuidString)")
            DebugCenterValueRow(title: "Channel", value: intent.deliveryChannel.rawValue)
            DebugCenterValueRow(title: "Scheduled", value: intent.scheduledAt.formatted(.iso8601))
        }
        .padding(.vertical, 4)
    }
}

private struct DebugGraphDeltaRow: View {
    let delta: GraphDelta

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(delta.source.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(delta.appliedAt == nil ? "unapplied" : "applied")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            DebugCenterValueRow(title: "ID", value: delta.id.uuidString)
            DebugCenterValueRow(title: "Operations", value: delta.operations.map { "\($0.kind.rawValue):\($0.targetType.rawValue)" }.joined(separator: "\n"))
            DebugCenterValueRow(title: "Confidence", value: delta.confidence.map { "\($0)" } ?? "none")
            DebugCenterValueRow(title: "Requires confirmation", value: DebugCenterFormatting.boolText(delta.requiresUserConfirmation))
        }
        .padding(.vertical, 4)
    }
}

private struct DebugHomeBoardItemDiagnosticsRow: View {
    let item: HomeBoardItemSnapshot
    let onAction: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.cardKind.rawValue)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(item.layout.layer.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(debugHomeBoardTitle(item))
                .font(.subheadline.weight(.semibold))
            Text(item.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
            DebugCenterValueRow(title: "Key", value: item.compositionItem.itemKey)
            DebugCenterValueRow(title: "Target", value: "\(item.compositionItem.targetType.rawValue) · \(item.compositionItem.targetID.uuidString)")
            DebugCenterValueRow(title: "Span / priority", value: "\(item.layout.span.widthColumns)x\(item.layout.span.heightUnits) · \(item.priority)")
            DebugCenterValueRow(title: "Flags", value: "pinned=\(item.isPinned), hidden=\(item.isHidden), dismissed=\(item.dismissedAt?.formatted(.iso8601) ?? "nil")")
            DebugCenterValueRow(title: "Sources", value: item.sourceRecordIDs.isEmpty ? "none" : item.sourceRecordIDs.map(\.uuidString).joined(separator: "\n"))
            HStack {
                Button("Add") { onAction(item, .addToBoard) }
                Button(item.isPinned ? "Unpin" : "Pin") { onAction(item, .pin(!item.isPinned)) }
                Button("More") { onAction(item, .preferMore) }
                Button("Less") { onAction(item, .preferLess) }
                Button("Dismiss") { onAction(item, .dismiss) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

private struct DebugCenterValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct DebugCenterPayloadBlock: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    UIPasteboard.general.string = content
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            Text(content.isEmpty ? "empty" : content)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}

private struct DebugCenterProgressRow: View {
    let text: String

    var body: some View {
        HStack {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private func debugControlLabel(_ rawValue: String) -> String {
    rawValue
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        .replacingOccurrences(of: "_", with: " ")
        .capitalized
}

private func cloudGateReason(_ cloudEnabled: Bool, _ flagEnabled: Bool, flagName: String) -> String {
    var reasons: [String] = []
    if !cloudEnabled {
        reasons.append("cloudIntelligenceEnabled=false")
    }
    if !flagEnabled {
        reasons.append("\(flagName)=false")
    }
    return reasons.isEmpty ? "enabled" : "blocked: \(reasons.joined(separator: ", "))"
}

private func debugHomeBoardTitle(_ item: HomeBoardItemSnapshot) -> String {
    switch item.renderValue {
    case let .memory(memory):
        return memory.title
    case let .arc(arc):
        return arc.title
    case let .reflection(reflection):
        return reflection.title
    case let .clarificationQuestion(question, profile):
        return profile.map { "\($0.displayName): \(question.prompt)" } ?? question.prompt
    case let .yesterdayPanel(title, _, _):
        return title
    case let .systemPrompt(title, _, _):
        return title
    case let .contextCluster(title, _, _):
        return title
    case let .pendingAction(title, _, _):
        return title
    }
}

private func debugActionLabel(_ action: HomeBoardPreferenceAction) -> String {
    switch action {
    case .addToBoard:
        return "addToBoard"
    case let .pin(value):
        return "pin(\(value))"
    case let .resize(span):
        return "resize(\(span.widthColumns)x\(span.heightUnits))"
    case let .setUserOrder(value):
        return "setUserOrder(\(value))"
    case .preferMore:
        return "preferMore"
    case .preferLess:
        return "preferLess"
    case .resetFeedback:
        return "resetFeedback"
    case .hide:
        return "hide"
    case .dismiss:
        return "dismiss"
    }
}

private func isoDate(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

import Foundation
import SwiftData

extension MoryMemoryRepository {
    // MARK: - Debug & Quality Tuning

    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot {
        let memories = try fetchRecentMemories(limit: nil)
        return try debugDiagnosticsService.fetchDiagnostics(
            targetType: targetType,
            targetID: targetID,
            modelContext: modelContext,
            memories: memories,
            pipelineStatusFetcher: fetchPipelineStatus,
            recordAnalysisFetcher: fetchRecordAnalysis,
            artifactsFetcher: fetchArtifacts,
            latestReflectionTrace: latestReflectionTrace
        )
    }

    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws {
        let memories = try fetchRecentMemories(limit: nil)
        let graphContext = try graphQueryService.load(modelContext: modelContext, memories: memories)
        switch mode {
        case .analysisOnly:
            let recordID = try resolveRecordIDViaGraph(targetType: targetType, targetID: targetID, graphContext: graphContext)
            guard let recordID else { throw CocoaError(.fileNoSuchFile) }
            try await refreshMemoryPipeline(recordID: recordID)
        case .graphArcReflection:
            let recordID = try resolveRecordIDViaGraph(targetType: targetType, targetID: targetID, graphContext: graphContext)
            guard let recordID else { throw CocoaError(.fileNoSuchFile) }
            try await rerunGraphArcReflection(recordID: recordID)
        case .reflectionReplay:
            let target = try debugDiagnosticsService.fetchDiagnostics(
                targetType: targetType,
                targetID: targetID,
                modelContext: modelContext,
                memories: memories,
                pipelineStatusFetcher: fetchPipelineStatus,
                recordAnalysisFetcher: fetchRecordAnalysis,
                artifactsFetcher: fetchArtifacts,
                latestReflectionTrace: latestReflectionTrace
            )
            guard let reflectionID = target.target?.reflection?.reflection.id else {
                throw CocoaError(.fileNoSuchFile)
            }
            let trace = try await replayDebugReflection(reflectionID: reflectionID)
            if let trace {
                latestReflectionTrace = trace
            } else {
                latestReflectionTrace = await analysisService.latestDebugTrace()
            }
        }
    }

    func resolveRecordIDViaGraph(targetType: DebugAnalysisTarget, targetID: UUID?, graphContext: MemoryGraphContext) throws -> UUID? {
        switch targetType {
        case .memory:
            if let targetID { return targetID }
            return try fetchRecentMemories(limit: 1).first?.record.id
        case .arc:
            return graphContext.arcs.first(where: { $0.id == targetID })?.sourceRecordIDs.first
                ?? graphContext.arcs.first?.sourceRecordIDs.first
        case .reflection:
            return graphContext.reflections.first(where: { $0.id == targetID })?.sourceRecordIDs.first
                ?? graphContext.reflections.first?.sourceRecordIDs.first
        }
    }

    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot] {
        let fixtureCount = max(1, count)
        var fixtures: [DebugMemoryFixtureSnapshot] = []
        for index in 0..<fixtureCount {
            let draft = MemoryCaptureDraft(
                title: "Debug fixture \(index + 1)",
                rawText: "Fixture \(index + 1) with Linh and a planning note.",
                mood: "reflective",
                inputContext: "debug fixture seed",
                provenance: CaptureProvenance(originCategory: .debug, sourceKind: .debugFixture)
            )
            let memory = try await createMemory(from: draft)
            try await refreshMemoryPipeline(recordID: memory.record.id)
            if let fixture = try fetchDebugFixtureSnapshot(recordID: memory.record.id) {
                fixtures.append(fixture)
            }
        }
        return fixtures
    }

    func clearDebugFixtures() throws {
        let records = try fetchRecordShells().filter {
            $0.debugFixtureSeededAt != nil || $0.inputContext == "debug fixture seed"
        }
        for record in records {
            try debugDiagnosticsService.deleteRecord(recordID: record.id, modelContext: modelContext)
        }
        try save()
    }

    func clearAllLocalData() throws {
        try deleteAll(NotificationIntentStore.self)
        try deleteAll(NotificationManagementEventStore.self)
        try externalCaptureInboxStore.clear()
        try deleteAll(HomeBoardSignalStore.self)
        try deleteAll(GraphDeltaStore.self)
        try deleteAll(IntelligenceJobStore.self)
        try deleteAll(CorrectionEventStore.self)
        try deleteAll(EntityTombstoneStore.self)
        try deleteAll(ClarificationQuestionStore.self)
        try deleteAll(PlaceProfileStore.self)
        try deleteAll(SelfProfileStore.self)
        try deleteAll(PersonProfileStore.self)
        try deleteAll(AffectSnapshotStore.self)
        try deleteAll(EntityProfileStore.self)
        try deleteAll(HomeBoardPreferenceStore.self)
        try deleteAll(CompositionItemStore.self)
        try deleteAll(CompositionStore.self)
        try deleteAll(BoardStore.self)
        try deleteAll(ArtifactEntityLinkStore.self)
        try deleteAll(EntityEdgeStore.self)
        try deleteAll(EntityNodeStore.self)
        try deleteAll(RecordAnalysisSnapshotStore.self)
        try deleteAll(MemoryPipelineStatusStore.self)
        try deleteAll(ReflectionSnapshotStore.self)
        try deleteAll(TemporalArcStore.self)
        try deleteAll(MemoryDetailPresentationPreferenceStore.self)
        try deleteAll(ArtifactStore.self)
        try deleteAll(RecordShellStore.self)
        latestReflectionTrace = nil
        try save()
        Task { @MainActor [spotlightIndexService, spotlightItemBuilder] in
            try? await spotlightIndexService.deleteDomain(spotlightItemBuilder.memoryDomain)
        }
    }

    // MARK: - Quality Tuning (cont.)

    func fetchQualityTuningPreference() throws -> QualityTuningPreference {
        let syncKey = QualityTuningPreference.defaultSyncKey
        let descriptor = FetchDescriptor<QualityTuningPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        guard let store = try modelContext.fetch(descriptor).first else {
            return .defaults
        }
        return makeQualityTuningPreference(from: store)
    }

    func saveQualityTuningPreference(_ preference: QualityTuningPreference) throws {
        let syncKey = preference.syncKey
        let descriptor = FetchDescriptor<QualityTuningPreferenceStore>(
            predicate: #Predicate { $0.syncKey == syncKey }
        )
        let data = try JSONEncoder().encode(preference.thresholds)
        if let store = try modelContext.fetch(descriptor).first {
            store.id = preference.id
            store.schemaVersion = preference.schemaVersion
            store.promptProfileRawValue = preference.promptProfile.rawValue
            store.thresholdsData = data
            store.notes = preference.notes
            store.updatedAt = preference.updatedAt
        } else {
            modelContext.insert(
                QualityTuningPreferenceStore(
                    id: preference.id,
                    schemaVersion: preference.schemaVersion,
                    syncKey: preference.syncKey,
                    promptProfileRawValue: preference.promptProfile.rawValue,
                    thresholdsData: data,
                    notes: preference.notes,
                    updatedAt: preference.updatedAt
                )
            )
        }
        try save()
    }

    func runQualityTuningScenario(_ request: QualityTuningRunRequest) async throws -> QualityTuningRunReport {
        QualityTuningRuntime.isEnabled = true
        QualityTuningRuntime.promptProfile = request.promptProfile
        QualityTuningRuntime.thresholds = request.thresholds
        QualityTuningRuntime.activeRecordScope = []
        defer { QualityTuningRuntime.activeRecordScope = nil }

        var createdMemories: [MemorySummary] = []
        let sessionID = UUID()
        for draft in makeQualityTuningDrafts(from: request.scenario, sessionID: sessionID) {
            let memory = try await createMemory(from: draft)
            QualityTuningRuntime.activeRecordScope = Set(createdMemories.map(\.record.id) + [memory.record.id])
            try await refreshMemoryPipeline(recordID: memory.record.id)
            createdMemories.append(memory)
        }

        guard let last = createdMemories.last else {
            throw CocoaError(.fileNoSuchFile)
        }

        let diagnostics = try fetchDebugDiagnostics(targetType: .memory, targetID: last.record.id)
        let reportRecordIDs = createdMemories.map(\.record.id)
        let arcs = try fetchTemporalArcs(limit: nil).filter { arc in
            arc.sourceRecordIDs.contains { reportRecordIDs.contains($0) }
        }
        let reflections = try fetchReflections(limit: nil).filter { reflection in
            reflection.sourceRecordIDs.contains { reportRecordIDs.contains($0) }
                || arcs.contains(where: { $0.id == reflection.linkedTemporalArcID })
        }
        let expectationPassed = evaluateQualityTuningExpectation(
            request.scenario.expectation,
            recordIDs: reportRecordIDs,
            arcs: arcs,
            reflections: reflections
        )

        return QualityTuningRunReport(
            scenarioTitle: request.scenario.title,
            promptProfile: request.promptProfile,
            thresholdsSummary: request.thresholds.summary,
            requestID: diagnostics.pipelineTrace?.requestID ?? latestReflectionTrace?.requestID,
            recordIDs: reportRecordIDs,
            expectation: request.scenario.expectation,
            expectationPassed: expectationPassed,
            requestBody: diagnostics.analyzePayload?.requestBody ?? "",
            rawResponseBody: diagnostics.analyzePayload?.responseBody ?? "",
            filteredSummary: makeQualityTuningFilteredSummary(diagnostics),
            storedSummary: makeQualityTuningStoredSummary(diagnostics: diagnostics, arcs: arcs, reflections: reflections),
            gates: makeQualityTuningGateSnapshots(diagnostics, expectation: request.scenario.expectation),
            createdAt: .now
        )
    }

    func makeQualityTuningDrafts(from scenario: QualityTuningScenario, sessionID: UUID) -> [MemoryCaptureDraft] {
        func draft(title: String, body: String, mood: String?, context: String, source: CaptureSource, artifacts: [CaptureArtifactDraft]) -> MemoryCaptureDraft {
            MemoryCaptureDraft(
                title: title,

                rawText: body,
                mood: mood,
                inputContext: [
                    "quality tuning session: \(sessionID.uuidString)",
                    "quality tuning lab: \(scenario.id.rawValue)",
                    context.trimmedOrNil
                ].compactMap { $0 }.joined(separator: "\n"),
                provenance: CaptureProvenance(
                    originCategory: .debug,
                    sourceKind: source.defaultProvenanceSourceKind
                ),
                artifacts: artifacts.isEmpty ? [.text(title: title, body: body)] : artifacts
            )
        }

        switch scenario.id {
        case .twoRelatedEvents:
            let firstBody = "First planning walk with Linh clarified the launch checklist and the decision to reduce scope."
            return [
                draft(
                    title: "Two related events - first",
                    body: firstBody,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: [.text(title: "Two related events - first", body: firstBody)]
                ),
                draft(
                    title: scenario.title,
                    body: scenario.body,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: scenario.artifacts
                )
            ]
        case .weakRelatedEvents:
            return [
                draft(title: "Weak related - calendar", body: "Calendar reminder to move the dentist appointment.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Weak related - calendar", body: "Calendar reminder to move the dentist appointment.")]),
                draft(title: "Weak related - grocery", body: "Buy lemons, rice, and paper towels after work.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Weak related - grocery", body: "Buy lemons, rice, and paper towels after work.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .denseUnrelatedHistory:
            return [
                draft(title: "Dense history - dentist", body: "Move the dentist appointment from Tuesday to Thursday.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Dense history - dentist", body: "Move the dentist appointment from Tuesday to Thursday.")]),
                draft(title: "Dense history - groceries", body: "Buy lemons, rice, paper towels, and batteries after work.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Dense history - groceries", body: "Buy lemons, rice, paper towels, and batteries after work.")]),
                draft(title: "Dense history - receipt", body: "Receipt photo import with weak OCR and no personal meaning.", mood: nil, context: scenario.context, source: .photo, artifacts: [.photo(title: "Receipt screenshot", summary: "OCR ORC receipt image artifact", filename: "dense_receipt.jpg", imageData: nil, thumbnailData: nil, ocrText: "OCR ORC receipt image artifact")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .recurringCareerHistory:
            return [
                draft(title: "Career transition - first", body: "I noticed relief after admitting to Linh that the current launch scope is too wide.", mood: "relieved", context: scenario.context, source: .composer, artifacts: [.text(title: "Career transition - first", body: "I noticed relief after admitting to Linh that the current launch scope is too wide.")]),
                draft(title: "Career transition - second", body: "During planning I chose the smaller launch scope and wrote down the roles I need to hand off.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Career transition - second", body: "During planning I chose the smaller launch scope and wrote down the roles I need to hand off.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .aliasSamePersonHistory:
            return [
                draft(title: "Alias history - Alexander", body: "Alexander Chen said the current launch plan feels too loud and asked for a quieter rollout.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Alias history - Alexander", body: "Alexander Chen said the current launch plan feels too loud and asked for a quieter rollout.")]),
                draft(title: "Alias history - Alex", body: "Alex Chen repeated that the quieter launch plan would help the team finish carefully.", mood: "steady", context: scenario.context, source: .composer, artifacts: [.text(title: "Alias history - Alex", body: "Alex Chen repeated that the quieter launch plan would help the team finish carefully.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .sameNameDifferentPeople:
            return [
                draft(title: "Same-name work Alex", body: "Alex from work asked me to reduce launch scope before the review.", mood: "focused", context: scenario.context, source: .composer, artifacts: [.text(title: "Same-name work Alex", body: "Alex from work asked me to reduce launch scope before the review.")]),
                draft(title: "Same-name neighbor Alex", body: "Alex from the apartment lobby reminded me about the package shelf.", mood: nil, context: scenario.context, source: .composer, artifacts: [.text(title: "Same-name neighbor Alex", body: "Alex from the apartment lobby reminded me about the package shelf.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .relationshipConflictShift:
            return [
                draft(title: "Conflict shift - first", body: "Linh and I argued during the review because decisions were changing live in the room.", mood: "tense", context: scenario.context, source: .composer, artifacts: [.text(title: "Conflict shift - first", body: "Linh and I argued during the review because decisions were changing live in the room.")]),
                draft(title: "Conflict shift - second", body: "Before the next review, Linh suggested writing scope decisions down so we stop debating from memory.", mood: "careful", context: scenario.context, source: .composer, artifacts: [.text(title: "Conflict shift - second", body: "Before the next review, Linh suggested writing scope decisions down so we stop debating from memory.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        case .longTimelineRecurringHistory:
            return [
                draft(title: "Long timeline - January", body: "In January I protected Monday morning for writing and finished the essay before meetings.", mood: "calm", context: scenario.context, source: .composer, artifacts: [.text(title: "Long timeline - January", body: "In January I protected Monday morning for writing and finished the essay before meetings.")]),
                draft(title: "Long timeline - March", body: "In March I lost the morning block to meetings and the writing slipped again.", mood: "frustrated", context: scenario.context, source: .composer, artifacts: [.text(title: "Long timeline - March", body: "In March I lost the morning block to meetings and the writing slipped again.")]),
                draft(title: scenario.title, body: scenario.body, mood: scenario.mood, context: scenario.context, source: scenario.captureSource, artifacts: scenario.artifacts)
            ]
        default:
            return [
                draft(
                    title: scenario.title,
                    body: scenario.body,
                    mood: scenario.mood,
                    context: scenario.context,
                    source: scenario.captureSource,
                    artifacts: scenario.artifacts
                )
            ]
        }
    }


    // MARK: - Reflections & Debug (cont.)

    func saveReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .saved)
    }

    func dismissReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .dismissed)
    }

    func archiveReflection(reflectionID: UUID) async throws {
        try updateReflectionStatus(reflectionID: reflectionID, status: .archived)
    }

    func rerunGraphArcReflection(recordID: UUID) async throws {
        try await refreshMemoryPipeline(recordID: recordID)
    }

    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot {
        let draft = MemoryCaptureDraft(
            title: "Late train, quiet insight",
            rawText: "Missed the express home after dinner with Linh and ended up walking twenty minutes in the rain. It felt frustrating at first, but the walk made the next quarter plan click into place.",
            mood: "reflective",
            inputContext: "post-dinner voice memo transcribed to text",
            provenance: CaptureProvenance(originCategory: .debug, sourceKind: .debugFixture)
        )
        let memory = try await createMemory(from: draft)

        guard let snapshot = try fetchDebugFixtureSnapshot(recordID: memory.record.id) else {
            throw CocoaError(.coderInvalidValue)
        }
        return snapshot
    }

    func replayDebugReflection(reflectionID: UUID) async throws -> DebugPipelineTraceSnapshot? {
        let memories = try fetchRecentMemories(limit: nil)
        return try await debugDiagnosticsService.replayReflection(
            reflectionID: reflectionID,
            modelContext: modelContext,
            memories: memories,
            analysisService: analysisService
        )
    }

    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot? {
        try debugDiagnosticsService.fetchFixtureSnapshot(
            recordID: recordID,
            modelContext: modelContext,
            artifactsFetcher: fetchArtifacts,
            recordAnalysisFetcher: fetchRecordAnalysis,
            pipelineStatusFetcher: fetchPipelineStatus
        )
    }

}

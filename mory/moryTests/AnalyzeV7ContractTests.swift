import XCTest
@testable import mory

@MainActor
final class AnalyzeV7ContractTests: XCTestCase {
    func testRequestBuilderIncludesContextPackMoodEvidenceAndPrivacyBudget() throws {
        let now = Date(timeIntervalSince1970: 1_768_864_000)
        let record = RecordShell(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            createdAt: now,
            updatedAt: now,
            captureSource: .voice,
            rawText: "我只是开玩笑地说自己很烦，但其实是在吐槽。",
            userMood: "吐槽",
            inputContext: "voice note"
        )
        let artifact = Artifact(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            recordID: record.id,
            kind: .text,
            title: "Voice transcript",
            summary: "开玩笑地吐槽",
            textContent: record.rawText,
            createdAt: now,
            updatedAt: now
        )
        let snapshot = AffectSnapshot(
            recordID: record.id,
            valence: 0.1,
            arousal: 0.6,
            dominance: 0.7,
            intensity: 0.5,
            labels: [.mockFrustrated],
            toneHints: [.joking],
            sources: [.userSelected],
            confidence: 0.82,
            evidence: [AffectEvidence(source: .userSelected, summary: "user marked this as joking", confidence: 0.82, createdAt: now)],
            userConfirmed: true,
            createdAt: now,
            updatedAt: now
        )
        let sensitiveID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        let payload = AnalyzeV7RequestBuilder().build(
            record: record,
            artifacts: [artifact],
            knownEntities: [EntityReference(id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!, kind: .person, name: "室友", aliases: ["roommate"], confidence: 0.7)],
            contextPack: makeContextPack(targetRecordID: record.id, sensitiveID: sensitiveID, builtAt: now),
            affectSnapshots: [snapshot],
            clientRequestID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
        )

        let data = try JSONEncoder().encode(payload)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertEqual(payload.schemaVersion, 7)
        XCTAssertEqual(payload.clientRequestID, "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")
        XCTAssertEqual(payload.moodEvidence.first?.toneHints, ["joking"])
        XCTAssertEqual(payload.contextPack.relatedMemories.count, 1)
        XCTAssertEqual(payload.contextPack.privacyDecisions.first?.action, ContextPrivacyAction.drop.rawValue)
        XCTAssertTrue(json.contains("safe recurring dinner evidence"))
        XCTAssertFalse(json.contains("diagnosis detail should never be sent"))
        XCTAssertTrue(json.contains("\"supports_proposal_only_writeback\":true"))
    }

    func testResponseMapperKeepsAnalyzeV7OutputAsLocalProposals() throws {
        let recordID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let entityID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        let response = AnalyzeV7ResponseEnvelope(
            analysis: AnalyzeResponseEnvelope(
                tags: ["relationship"],
                retrievalTerms: ["roommate"],
                emotion: .init(label: "stressed", intensity: 0.8, confidence: 0.7, interpretation: nil),
                entities: [],
                candidateEdges: [],
                insight: "The record may be a tense but joking roommate moment.",
                summary: "Roommate joking context.",
                salienceScore: 0.73,
                followUp: nil,
                reflectionHint: "Check whether roommate stress is joking or serious over time."
            ),
            affectProposals: [
                .init(
                    proposalID: "11111111-1111-1111-1111-111111111111",
                    valence: -0.2,
                    arousal: 0.65,
                    dominance: 0.5,
                    intensity: 0.6,
                    labels: ["mockFrustrated"],
                    toneHints: ["joking"],
                    appraisal: nil,
                    confidence: 0.66,
                    evidence: [.init(recordID: recordID.uuidString, artifactID: nil, snippet: "voice tone looked playful", createdAt: nil)],
                    requiresConfirmation: true,
                    rawInput: "我真服了"
                )
            ],
            graphDeltaProposals: [
                .init(
                    proposalID: "22222222-2222-2222-2222-222222222222",
                    operations: [.init(kind: GraphDeltaOperationKind.addAlias.rawValue, targetType: ClarificationTargetType.entity.rawValue, targetID: entityID.uuidString, relatedID: nil, stringValue: "室友", numericValue: nil, metadata: ["proposal_source": "test"])],
                    confidence: 0.71,
                    requiresConfirmation: true,
                    evidence: []
                )
            ],
            profileUpdateProposals: [
                .init(
                    proposalID: "33333333-3333-3333-3333-333333333333",
                    targetEntityID: entityID.uuidString,
                    profileKind: "person",
                    field: "relationshipToUser",
                    proposedValue: EntityRelationshipToUser.friend.rawValue,
                    confidence: 0.62,
                    evidence: [],
                    requiresConfirmation: true
                )
            ],
            mergeSplitCandidates: [
                .init(
                    candidateID: "44444444-4444-4444-4444-444444444444",
                    kind: "mergePerson",
                    sourceEntityIDs: [entityID.uuidString],
                    targetEntityID: entityID.uuidString,
                    confidence: 0.58,
                    positiveEvidence: [],
                    negativeEvidence: [],
                    question: "Is this roommate the same person as Alex?"
                )
            ],
            reflectionCandidates: [
                .init(
                    candidateID: "55555555-5555-5555-5555-555555555555",
                    title: "Roommate tone pattern",
                    body: "A repeated joking frustration may be forming.",
                    evidenceSummary: "Two roommate dinner notes.",
                    confidence: 0.68,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: [],
                    sourceEntityIDs: [entityID.uuidString]
                )
            ],
            questionCandidates: [
                .init(
                    candidateID: "66666666-6666-6666-6666-666666666666",
                    kind: ClarificationQuestionKind.dailyReflection.rawValue,
                    prompt: "Was this joke or real frustration?",
                    reason: "Tone is uncertain.",
                    candidateAnswers: ["joke", "real frustration"],
                    confidence: 0.7,
                    sensitivity: QuestionSensitivity.normal.rawValue,
                    targetType: ClarificationTargetType.record.rawValue,
                    targetID: recordID.uuidString,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: []
                )
            ],
            quality: .init(confidence: 0.63, uncertaintyReasons: ["insufficient_longitudinal_evidence"], needsUserCheck: ["tone"])
        )

        let mapped = AnalyzeV7ResponseMapper().map(recordID: recordID, response: response)

        XCTAssertEqual(mapped.analysis.recordID, recordID)
        XCTAssertEqual(mapped.affectProposals.first?.toneHints, [.joking])
        XCTAssertEqual(mapped.graphDeltaProposals.count, 2)
        XCTAssertTrue(mapped.graphDeltaProposals.allSatisfy { $0.appliedAt == nil && $0.requiresUserConfirmation })
        XCTAssertEqual(mapped.reflectionProposals.first?.status, .suggested)
        XCTAssertEqual(mapped.questionProposals.first?.prompt, "Was this joke or real frustration?")
        XCTAssertEqual(mapped.mergeSplitQuestions.first?.kind, .entityMerge)
        XCTAssertEqual(mapped.quality.needsUserCheck, ["tone"])
    }

    func testAnalyzeV7ResponseDecodesLowContextQualityFlags() throws {
        let json = """
        {
          "analysis": {
            "tags": [],
            "emotion": {"label":"neutral","confidence":0.4},
            "entities": [],
            "candidate_edges": [],
            "insight": "Thin evidence.",
            "summary": "Thin evidence.",
            "retrieval_terms": [],
            "follow_up": null
          },
          "quality": {
            "confidence": 0.32,
            "uncertainty_reasons": ["thin_context", "missing_structured_mood_evidence"],
            "needs_user_check": ["tone"]
          }
        }
        """

        let decoded = try JSONDecoder().decode(AnalyzeV7ResponseEnvelope.self, from: Data(json.utf8))

        XCTAssertTrue(decoded.affectProposals.isEmpty)
        XCTAssertEqual(decoded.quality.uncertaintyReasons, ["thin_context", "missing_structured_mood_evidence"])
        XCTAssertEqual(decoded.quality.needsUserCheck, ["tone"])
    }

    func testProductionPipelineUsesAnalyzeV7AndPersistsProposals() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let legacyService = V7ProductionTestAnalysisService()
        let cloudService = V7ProductionTestCloudService(response: Self.makeProductionResponse())
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: legacyService,
            cloudIntelligenceService: cloudService
        )

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Production v7",
                rawText: "production v7 test record about Linh and planning",
                mood: "focused",
                captureSource: .composer,
                artifacts: [.text(title: "Production v7", body: "production v7 test record about Linh and planning")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let payloads = await cloudService.payloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.schemaVersion, 7)
        XCTAssertEqual(payloads.first?.contextPack.targetRecordID, memory.record.id.uuidString)
        XCTAssertNotNil(payloads.first?.contextPack.selfBrief)
        let legacyAnalyzeCallCount = await legacyService.analyzeCallCount()
        XCTAssertEqual(legacyAnalyzeCallCount, 0)

        let analysis = try XCTUnwrap(repository.fetchRecordAnalysis(recordID: memory.record.id))
        XCTAssertEqual(analysis.summary, "v7 production summary")
        let affectSnapshots = try repository.fetchAffectSnapshots(recordID: memory.record.id, limit: nil)
        XCTAssertTrue(affectSnapshots.contains { $0.labels.contains(.relieved) })
        XCTAssertEqual(try repository.fetchGraphDeltas(applied: nil, limit: nil).count, 1)
        XCTAssertTrue(try repository.fetchReflections(limit: nil).contains { $0.title == "Production v7 reflection" })
        XCTAssertTrue(try repository.fetchClarificationQuestions(status: nil, limit: nil).contains { $0.prompt == "Was this planning moment about Linh?" })
        XCTAssertTrue(try repository.fetchTemporalArcs(limit: nil).contains { $0.title == "Production v7 arc" })
        let status = try XCTUnwrap(repository.fetchPipelineStatus(recordID: memory.record.id))
        XCTAssertEqual(status.stage, .completed)
        XCTAssertEqual(status.lastHTTPStatusCode, 200)
        XCTAssertTrue(status.requestBody?.contains("\"schema_version\":7") == true)
        XCTAssertTrue(status.responseBody?.contains("v7 production summary") == true)
    }

    static func makeProductionResponse() -> AnalyzeV7ResponseEnvelope {
        let recordID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let entityID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        return AnalyzeV7ResponseEnvelope(
            analysis: AnalyzeResponseEnvelope(
                tags: ["planning"],
                retrievalTerms: [],
                emotion: .init(label: "neutral", intensity: 0.5, confidence: 0.5, interpretation: nil),
                entities: [.init(kind: "person", name: "Linh", canonicalName: "Linh", aliases: nil, confidence: 0.9, sourceArtifactIDs: [])],
                candidateEdges: [],
                insight: "test insight",
                summary: "v7 production summary",
                salienceScore: 0.5,
                followUp: nil,
                reflectionHint: nil
            ),
            affectProposals: [
                .init(
                    proposalID: "11111111-1111-1111-1111-111111111111",
                    valence: 0.1,
                    arousal: 0.5,
                    dominance: 0.5,
                    intensity: 0.5,
                    labels: [AffectLabel.relieved.rawValue],
                    toneHints: [],
                    appraisal: nil,
                    confidence: 0.6,
                    evidence: [],
                    requiresConfirmation: false,
                    rawInput: nil
                )
            ],
            graphDeltaProposals: [
                .init(
                    proposalID: "33333333-3333-3333-3333-333333333333",
                    operations: [.init(kind: GraphDeltaOperationKind.addAlias.rawValue, targetType: ClarificationTargetType.entity.rawValue, targetID: entityID.uuidString, relatedID: nil, stringValue: "L", numericValue: nil, metadata: [:])],
                    confidence: 0.7,
                    requiresConfirmation: true,
                    evidence: []
                )
            ],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [
                .init(
                    candidateID: "44444444-4444-4444-4444-444444444444",
                    title: "Production v7 arc",
                    summary: "A production v7 arc candidate.",
                    sourceRecordIDs: [recordID.uuidString],
                    confidence: 0.65
                )
            ],
            reflectionCandidates: [
                .init(
                    candidateID: "22222222-2222-2222-2222-222222222222",
                    title: "Production v7 reflection",
                    body: "Test body",
                    evidenceSummary: "Evidence",
                    confidence: 0.7,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: [],
                    sourceEntityIDs: []
                )
            ],
            questionCandidates: [
                .init(
                    candidateID: "55555555-5555-5555-5555-555555555555",
                    kind: ClarificationQuestionKind.dailyReflection.rawValue,
                    prompt: "Was this planning moment about Linh?",
                    reason: "V7 production test.",
                    candidateAnswers: ["yes", "no"],
                    confidence: 0.6,
                    sensitivity: QuestionSensitivity.normal.rawValue,
                    targetType: ClarificationTargetType.record.rawValue,
                    targetID: recordID.uuidString,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: []
                )
            ],
            quality: .init(confidence: 0.6, uncertaintyReasons: [], needsUserCheck: [])
        )
    }

    private func makeContextPack(targetRecordID: UUID, sensitiveID: UUID, builtAt: Date) -> AnalysisContextPack {
        let relatedID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
        return AnalysisContextPack(
            packID: UUID(uuidString: "88888888-8888-8888-8888-888888888888")!,
            targetRecordID: targetRecordID,
            selfBrief: SelfContextBrief(profile: SelfProfile(displayName: "Tester", aliases: ["我", "tester"]), maxCharacters: 400),
            relatedProfiles: [
                KnownProfileBrief(
                    entityID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    kind: .person,
                    displayName: "室友",
                    relationshipToUser: .friend,
                    mentionCount: 3,
                    commonContextLabels: ["dinner"],
                    confidence: 0.7,
                    inclusionReason: "entity overlap"
                )
            ],
            relatedMemories: [
                RelatedMemoryBrief(
                    recordID: relatedID,
                    title: "Dinner joke",
                    snippet: "safe recurring dinner evidence",
                    createdAt: builtAt,
                    userMood: "joking",
                    scoreBreakdown: ContextScoreBreakdown(
                        semanticSimilarity: 0.5,
                        entityOverlap: 0.2,
                        recencyWeight: 0.1,
                        salienceWeight: 0.1,
                        userConfirmedWeight: 0,
                        openDecisionWeight: 0,
                        affectSimilarityWeight: 0.1,
                        sensitivityPenalty: 0,
                        repeatedRejectedSignalPenalty: 0
                    ),
                    inclusionReasons: ["semantic", "entity overlap"]
                )
            ],
            relatedArcs: [
                RelatedArcBrief(
                    arcID: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
                    title: "Roommate dinners",
                    summary: "Recurring joking dinner moments.",
                    status: .candidate,
                    sourceRecordIDs: [relatedID],
                    score: 0.6
                )
            ],
            priorReflections: [
                PriorReflectionBrief(
                    reflectionID: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
                    title: "Joking tone",
                    evidenceSummary: "Past user correction said this phrase can be joking.",
                    status: .saved,
                    sourceRecordIDs: [relatedID],
                    confidence: 0.7
                )
            ],
            correctionSignals: [
                CorrectionSignalBrief(
                    id: UUID(uuidString: "34343434-3434-3434-3434-343434343434")!,
                    kind: .dailyReflection,
                    targetType: .record,
                    targetID: targetRecordID,
                    status: .answered,
                    summary: "User said similar phrase was joking.",
                    answeredAt: builtAt
                )
            ],
            affectHistory: [
                AffectHistoryBrief(
                    mood: "mockFrustrated",
                    count: 2,
                    latestRecordID: relatedID,
                    averageValence: 0.05,
                    averageArousal: 0.6,
                    averageDominance: 0.7,
                    toneHints: [.joking],
                    sources: [.userCorrected]
                )
            ],
            privacyDecisions: [
                ContextPrivacyDecision(sourceType: "memory", sourceID: sensitiveID, action: .drop, reason: "sensitive boundary")
            ],
            budget: ContextBudgetReport(
                limits: .phase1Default,
                selectedProfiles: 1,
                selectedRelatedMemories: 1,
                selectedArcs: 1,
                selectedReflections: 1,
                selectedCorrections: 1,
                selectedAffectHistory: 1,
                droppedByBudget: 0,
                droppedByPrivacy: 1
            ),
            retrieval: ContextPackRetrievalReport(
                semanticSearchStatus: "disabled",
                retrievalSources: ["recent"],
                candidateMemoryCount: 2,
                fallbackReason: "test"
            ),
            builtAt: builtAt
        )
    }
}

// MARK: - Test Doubles

private enum V7ProductionTestError: Error {
    case unsupported
}

private actor V7ProductionTestCloudService: CloudIntelligenceServing {
    let response: AnalyzeV7ResponseEnvelope
    private var capturedPayloads: [AnalyzeV7RequestPayload] = []

    init(response: AnalyzeV7ResponseEnvelope) {
        self.response = response
    }

    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        capturedPayloads.append(payload)
        return response
    }

    func payloads() -> [AnalyzeV7RequestPayload] {
        capturedPayloads
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw V7ProductionTestError.unsupported
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw V7ProductionTestError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw V7ProductionTestError.unsupported
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw V7ProductionTestError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw V7ProductionTestError.unsupported
    }
}

private actor V7ProductionTestAnalysisService: RecordAnalysisServing {
    private var analyzeCalls = 0

    func analyze(record: RecordShell, artifacts: [Artifact], knownEntities: [EntityReference]) async throws -> RecordAnalysisSnapshot {
        analyzeCalls += 1
        throw V7ProductionTestError.unsupported
    }

    func analyzeCallCount() -> Int {
        analyzeCalls
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw V7ProductionTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw V7ProductionTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? { nil }
}

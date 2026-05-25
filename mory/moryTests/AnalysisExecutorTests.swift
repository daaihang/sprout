import XCTest
@testable import mory

@MainActor
final class AnalysisExecutorTests: XCTestCase {
    func testRunPersistsAnalysisGraphAndProposalsThroughPorts() async throws {
        let fixture = PipelineFixture()
        let artifactID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let record = fixture.makeRecord(artifactIDs: [artifactID])
        let artifact = fixture.makeArtifact(id: artifactID, recordID: record.id)
        let response = Self.makeResponse(recordID: record.id)
        let cloud = PipelineTestCloudService(result: .success(response))
        let persist = PipelinePersistSpy()
        let tracing = PipelineTraceSpy()
        let query = PipelineQuerySpy(
            preContext: AnalysisPipelinePreAnalysisContext(
                entityNodes: [
                    EntityNode(
                        kind: .person,
                        displayName: "Known Linh",
                        aliases: ["L"],
                        provenanceRecordIDs: [record.id],
                        createdAt: fixture.now,
                        updatedAt: fixture.now,
                        confidence: 0.91
                    )
                ]
            ),
            postContext: AnalysisPipelinePostAnalysisContext(records: [record], artifacts: [artifact])
        )
        let contextProvider = PipelineContextProvider(pack: fixture.makeContextPack(recordID: record.id))
        let runtimeScope = PipelineRuntimeScope(activeRecordScope: [record.id])

        try await AnalysisExecutor().run(
            record: record,
            artifacts: [artifact],
            dependencies: AnalysisPipelineDependencies(
                cloudIntelligenceService: cloud,
                contextProvider: contextProvider,
                query: query,
                persist: persist,
                tracing: tracing,
                runtimeScope: runtimeScope
            )
        )

        let payloads = await cloud.payloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.knownEntities.first?.name, "Known Linh")
        XCTAssertEqual(query.receivedPreRecordScopes, [[record.id]])
        XCTAssertEqual(query.receivedPostRecordScopes, [[record.id]])
        XCTAssertEqual(persist.recordAnalyses.first?.summary, "Pipeline analysis summary")
        XCTAssertTrue(persist.entityNodes.contains { $0.displayName == "Linh" })
        XCTAssertTrue(persist.artifactEntityLinks.contains { $0.artifactID == artifactID })
        XCTAssertEqual(persist.affectSnapshots.count, 1)
        XCTAssertEqual(persist.graphDeltas.count, 1)
        XCTAssertEqual(persist.reflections.first?.title, "Pipeline reflection")
        XCTAssertEqual(persist.questions.first?.prompt, "Was this about Linh?")
        XCTAssertEqual(persist.temporalArcs.first?.title, "Pipeline arc")
        XCTAssertGreaterThanOrEqual(persist.saveCount, 3)
        XCTAssertNil(tracing.traces.last??.failedStage)
        XCTAssertEqual(tracing.traces.last??.statusCode, 200)
    }

    func testRunRecordsAnalysisFailureTraceAndDoesNotPersistGraph() async throws {
        let fixture = PipelineFixture()
        let record = fixture.makeRecord()
        let cloud = PipelineTestCloudService(result: .failure(PipelineTestError.cloudFailed))
        let persist = PipelinePersistSpy()
        let tracing = PipelineTraceSpy()

        do {
            try await AnalysisExecutor().run(
                record: record,
                artifacts: [],
                dependencies: AnalysisPipelineDependencies(
                    cloudIntelligenceService: cloud,
                    contextProvider: PipelineContextProvider(pack: fixture.makeContextPack(recordID: record.id)),
                    query: PipelineQuerySpy(),
                    persist: persist,
                    tracing: tracing,
                    runtimeScope: PipelineRuntimeScope()
                )
            )
            XCTFail("Expected analysis cloud failure to propagate.")
        } catch PipelineTestError.cloudFailed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(persist.recordAnalyses.isEmpty)
        XCTAssertTrue(persist.entityNodes.isEmpty)
        XCTAssertTrue(persist.graphDeltas.isEmpty)
        XCTAssertEqual(tracing.traces.last??.failedStage, "analysis")
    }

    func testRunCanUseScopedMockPortsWithoutModelContainer() async throws {
        let fixture = PipelineFixture()
        let includedRecordID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let excludedRecordID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let record = fixture.makeRecord(id: includedRecordID)
        let query = PipelineQuerySpy(
            preContext: AnalysisPipelinePreAnalysisContext(),
            postContext: AnalysisPipelinePostAnalysisContext(
                records: [record],
                temporalArcs: [
                    TemporalArc(
                        title: "Excluded",
                        summary: "Should only be supplied by query if in scope.",
                        status: .candidate,
                        sourceRecordIDs: [excludedRecordID],
                        sourceArtifactIDs: [],
                        sourceEntityIDs: [],
                        startDate: fixture.now,
                        endDate: fixture.now,
                        intensityScore: 0.5,
                        clusterStrength: 0.5,
                        createdAt: fixture.now,
                        updatedAt: fixture.now
                    )
                ]
            )
        )
        let cloud = PipelineTestCloudService(result: .success(Self.makeResponse(recordID: record.id)))

        try await AnalysisExecutor().run(
            record: record,
            artifacts: [],
            dependencies: AnalysisPipelineDependencies(
                cloudIntelligenceService: cloud,
                contextProvider: PipelineContextProvider(pack: fixture.makeContextPack(recordID: record.id)),
                query: query,
                persist: PipelinePersistSpy(),
                tracing: PipelineTraceSpy(),
                runtimeScope: PipelineRuntimeScope(activeRecordScope: [includedRecordID])
            )
        )

        XCTAssertEqual(query.receivedPreRecordScopes, [[includedRecordID]])
        XCTAssertEqual(query.receivedPostRecordScopes, [[includedRecordID]])
    }

    private static func makeResponse(recordID: UUID) -> AnalysisResponseEnvelope {
        let entityID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        return AnalysisResponseEnvelope(
            analysis: AnalysisRecordResponse(
                tags: ["planning"],
                retrievalTerms: ["Linh"],
                emotion: .init(label: "relieved", intensity: 0.6, confidence: 0.7, interpretation: nil),
                entities: [
                    .init(kind: "person", name: "Linh", canonicalName: "Linh", aliases: ["L"], confidence: 0.9, sourceArtifactIDs: [])
                ],
                candidateEdges: [],
                insight: "Pipeline analysis insight.",
                summary: "Pipeline analysis summary",
                salienceScore: 0.66,
                followUp: nil,
                reflectionHint: nil
            ),
            affectProposals: [
                .init(
                    proposalID: "33333333-3333-3333-3333-333333333333",
                    valence: 0.3,
                    arousal: nil,
                    dominance: nil,
                    intensity: 0.6,
                    labels: [AffectLabel.relieved.rawValue],
                    toneHints: [],
                    appraisal: nil,
                    confidence: 0.7,
                    evidence: [],
                    requiresConfirmation: false,
                    rawInput: nil
                )
            ],
            graphDeltaProposals: [
                .init(
                    proposalID: "44444444-4444-4444-4444-444444444444",
                    operations: [
                        .init(
                            kind: GraphDeltaOperationKind.addAlias.rawValue,
                            targetType: ClarificationTargetType.entity.rawValue,
                            targetID: entityID.uuidString,
                            relatedID: nil,
                            stringValue: "L",
                            numericValue: nil,
                            metadata: [:]
                        )
                    ],
                    confidence: 0.7,
                    requiresConfirmation: true,
                    evidence: []
                )
            ],
            profileUpdateProposals: [],
            mergeSplitCandidates: [],
            arcCandidates: [
                .init(
                    candidateID: "55555555-5555-5555-5555-555555555555",
                    title: "Pipeline arc",
                    summary: "Pipeline arc summary.",
                    sourceRecordIDs: [recordID.uuidString],
                    confidence: 0.7
                )
            ],
            reflectionCandidates: [
                .init(
                    candidateID: "66666666-6666-6666-6666-666666666666",
                    title: "Pipeline reflection",
                    body: "Pipeline reflection body.",
                    evidenceSummary: "Pipeline evidence.",
                    confidence: 0.72,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: [],
                    sourceEntityIDs: []
                )
            ],
            questionCandidates: [
                .init(
                    candidateID: "77777777-7777-7777-7777-777777777777",
                    kind: ClarificationQuestionKind.dailyReflection.rawValue,
                    prompt: "Was this about Linh?",
                    reason: "Pipeline question.",
                    candidateAnswers: ["yes", "no"],
                    confidence: 0.65,
                    sensitivity: QuestionSensitivity.normal.rawValue,
                    targetType: ClarificationTargetType.record.rawValue,
                    targetID: recordID.uuidString,
                    sourceRecordIDs: [recordID.uuidString],
                    sourceArtifactIDs: []
                )
            ],
            quality: .init(confidence: 0.7, uncertaintyReasons: [], needsUserCheck: [])
        )
    }
}

private struct PipelineFixture {
    let now = Date(timeIntervalSince1970: 1_770_000_000)

    func makeRecord(id: UUID = UUID(), artifactIDs: [UUID] = []) -> RecordShell {
        RecordShell(
            id: id,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Planning with Linh.",
            artifactIDs: artifactIDs
        )
    }

    func makeArtifact(id: UUID = UUID(), recordID: UUID) -> Artifact {
        Artifact(
            id: id,
            recordID: recordID,
            kind: .text,
            title: "Transcript",
            summary: "Planning with Linh.",
            textContent: "Planning with Linh.",
            createdAt: now,
            updatedAt: now
        )
    }

    func makeContextPack(recordID: UUID) -> AnalysisContextPack {
        AnalysisContextPack(
            packID: UUID(),
            targetRecordID: recordID,
            selfBrief: SelfContextBrief(profile: SelfProfile(displayName: "Tester"), maxCharacters: 200),
            relatedProfiles: [],
            relatedMemories: [],
            relatedArcs: [],
            priorReflections: [],
            correctionSignals: [],
            affectHistory: [],
            privacyDecisions: [],
            budget: ContextBudgetReport(
                limits: .phase1Default,
                selectedProfiles: 0,
                selectedRelatedMemories: 0,
                selectedArcs: 0,
                selectedReflections: 0,
                selectedCorrections: 0,
                selectedAffectHistory: 0,
                droppedByBudget: 0,
                droppedByPrivacy: 0
            ),
            retrieval: ContextPackRetrievalReport(
                semanticSearchStatus: "disabled",
                retrievalSources: ["test"],
                candidateMemoryCount: 0,
                fallbackReason: nil
            ),
            builtAt: now
        )
    }
}

@MainActor
private final class PipelineQuerySpy: AnalysisPipelineQuerying {
    var preContext: AnalysisPipelinePreAnalysisContext
    var postContext: AnalysisPipelinePostAnalysisContext
    private(set) var receivedPreRecordScopes: [Set<UUID>?] = []
    private(set) var receivedPostRecordScopes: [Set<UUID>?] = []

    init() {
        self.preContext = AnalysisPipelinePreAnalysisContext()
        self.postContext = AnalysisPipelinePostAnalysisContext()
    }

    init(
        preContext: AnalysisPipelinePreAnalysisContext,
        postContext: AnalysisPipelinePostAnalysisContext
    ) {
        self.preContext = preContext
        self.postContext = postContext
    }

    func loadPreAnalysisContext(recordScope: Set<UUID>?) throws -> AnalysisPipelinePreAnalysisContext {
        receivedPreRecordScopes.append(recordScope)
        return preContext
    }

    func loadPostAnalysisContext(
        replacingWith analysis: RecordAnalysisSnapshot,
        recordScope: Set<UUID>?
    ) throws -> AnalysisPipelinePostAnalysisContext {
        receivedPostRecordScopes.append(recordScope)
        var context = postContext
        context.analyses.removeAll { $0.recordID == analysis.recordID }
        context.analyses.append(analysis)
        return context
    }
}

@MainActor
private final class PipelinePersistSpy: AnalysisPipelinePersisting {
    private(set) var recordAnalyses: [RecordAnalysisSnapshot] = []
    private(set) var placeProfiles: [PlaceProfile] = []
    private(set) var entityNodes: [EntityNode] = []
    private(set) var entityEdges: [EntityEdge] = []
    private(set) var artifactEntityLinks: [ArtifactEntityLink] = []
    private(set) var temporalArcs: [TemporalArc] = []
    private(set) var reflections: [ReflectionSnapshot] = []
    private(set) var affectSnapshots: [AffectSnapshot] = []
    private(set) var graphDeltas: [GraphDelta] = []
    private(set) var questions: [ClarificationQuestion] = []
    private(set) var saveCount = 0

    func persistRecordAnalysis(_ analysis: RecordAnalysisSnapshot) throws { recordAnalyses.append(analysis) }
    func persistPlaceProfile(_ profile: PlaceProfile) throws { placeProfiles.append(profile) }
    func persistEntityNode(_ entityNode: EntityNode) throws { entityNodes.append(entityNode) }
    func persistEntityEdge(_ entityEdge: EntityEdge) throws { entityEdges.append(entityEdge) }
    func persistArtifactEntityLink(_ artifactEntityLink: ArtifactEntityLink) throws { artifactEntityLinks.append(artifactEntityLink) }
    func persistTemporalArc(_ temporalArc: TemporalArc) throws { temporalArcs.append(temporalArc) }
    func persistReflection(_ reflection: ReflectionSnapshot) throws { reflections.append(reflection) }
    func persistAffectSnapshot(_ snapshot: AffectSnapshot) throws { affectSnapshots.append(snapshot) }
    func persistGraphDelta(_ delta: GraphDelta) throws { graphDeltas.append(delta) }
    func persistClarificationQuestion(_ question: ClarificationQuestion) throws { questions.append(question) }
    func saveAnalysisPipelineChanges() throws { saveCount += 1 }
}

@MainActor
private final class PipelineTraceSpy: AnalysisPipelineTracing {
    private(set) var traces: [DebugPipelineTraceSnapshot?] = []

    func setDebugTrace(_ trace: DebugPipelineTraceSnapshot?) {
        traces.append(trace)
    }
}

@MainActor
private final class PipelineContextProvider: AnalysisPipelineContextPacking {
    let pack: AnalysisContextPack
    var affectSnapshots: [AffectSnapshot]

    init(pack: AnalysisContextPack, affectSnapshots: [AffectSnapshot] = []) {
        self.pack = pack
        self.affectSnapshots = affectSnapshots
    }

    func buildContextPack(targetRecordID: UUID) async throws -> AnalysisContextPack {
        pack
    }

    func fetchAffectSnapshots(recordID: UUID, limit: Int?) throws -> [AffectSnapshot] {
        Array(affectSnapshots.prefix(limit ?? affectSnapshots.count))
    }
}

@MainActor
private struct PipelineRuntimeScope: AnalysisPipelineRuntimeScoping {
    var activeRecordScope: Set<UUID>?
}

private actor PipelineTestCloudService: CloudIntelligenceServing {
    enum Result {
        case success(AnalysisResponseEnvelope)
        case failure(Error)
    }

    private let result: Result
    private var capturedPayloads: [AnalysisRequestPayload] = []

    init(result: Result) {
        self.result = result
    }

    func analyzeMemory(_ payload: AnalysisRequestPayload) async throws -> AnalysisResponseEnvelope {
        capturedPayloads.append(payload)
        switch result {
        case let .success(response):
            return response
        case let .failure(error):
            throw error
        }
    }

    func payloads() -> [AnalysisRequestPayload] {
        capturedPayloads
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw PipelineTestError.unsupported
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw PipelineTestError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw PipelineTestError.unsupported
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw PipelineTestError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw PipelineTestError.unsupported
    }
}

private enum PipelineTestError: Error {
    case cloudFailed
    case unsupported
}

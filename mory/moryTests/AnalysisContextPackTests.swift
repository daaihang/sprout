import SwiftData
import XCTest
@testable import mory

@MainActor
final class AnalysisContextPackTests: XCTestCase {
    func testSelfReferenceResolverHandlesSelfAndOwnedRoleMentions() {
        let profile = SelfProfile(displayName: "User", aliases: ["我", "Mory Tester"])
        let resolver = SelfReferenceResolver()

        let resolutions = resolver.resolve(text: "我和我的室友又因为水电费吵了一架", selfProfile: profile)

        XCTAssertTrue(resolutions.contains { $0.kind == .selfMention && $0.targetEntityID == profile.selfEntityID })
        XCTAssertTrue(resolutions.contains { $0.kind == .ownedRoleMention })
        XCTAssertFalse(resolutions.contains { $0.kind == .ambiguousRoleMention })
    }

    func testSelfReferenceResolverDoesNotMatchChinesePluralWeAsMe() {
        let profile = SelfProfile(displayName: "User", aliases: ["我"])
        let resolver = SelfReferenceResolver()

        let plural = resolver.resolve(text: "我们去吃饭", selfProfile: profile)
        let singular = resolver.resolve(text: "我去吃饭", selfProfile: profile)

        XCTAssertFalse(plural.contains { $0.kind == .selfMention })
        XCTAssertTrue(singular.contains { $0.kind == .selfMention && $0.targetEntityID == profile.selfEntityID })
    }

    func testContextPackBuildsWithSemanticDisabledFallbackAndBudgetCap() async throws {
        let fixture = makeFixture()
        let repository = fixture.repository
        var preferences = try repository.fetchIntelligencePreferences()
        preferences.semanticSearchEnabled = false
        try repository.saveIntelligencePreferences(preferences)
        var flags = try repository.fetchV6FeatureFlags()
        flags.semanticSearch = false
        try repository.saveV6FeatureFlags(flags)

        let target = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Career decision",
                rawText: "I am deciding whether to switch jobs after a tense planning cycle with Alex.",
                mood: "uncertain",
                captureSource: .manual
            )
        )
        for index in 0..<18 {
            _ = try await repository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Planning memory \(index)",
                    rawText: "Alex and I discussed job planning, pressure, and what decision would feel sustainable. Item \(index).",
                    mood: index.isMultiple(of: 2) ? "uncertain" : "tired",
                    captureSource: .manual
                )
            )
        }
        try repository.upsertEntityProfile(
            EntityProfile(
                entityID: UUID(),
                kind: .person,
                displayName: "Alex",
                relationshipToUser: .coworker,
                mentionCount: 10,
                confirmationState: .userConfirmed,
                confidence: 0.95
            )
        )

        let pack = try await ContextPackBuilder(repository: repository).build(targetRecordID: target.id)

        XCTAssertEqual(pack.targetRecordID, target.id)
        XCTAssertEqual(pack.retrieval.semanticSearchStatus, "disabled")
        XCTAssertEqual(pack.retrieval.fallbackReason, "Semantic search gate is disabled.")
        XCTAssertLessThanOrEqual(pack.relatedMemories.count, ContextBudgetLimits.phase1Default.maxRelatedMemories)
        XCTAssertGreaterThan(pack.relatedMemories.count, 0)
        XCTAssertTrue(pack.relatedProfiles.contains { $0.displayName == "Alex" })
        XCTAssertEqual(pack.budget.selectedRelatedMemories, pack.relatedMemories.count)
        XCTAssertGreaterThanOrEqual(pack.budget.droppedByBudget, 6)
    }

    func testContextPackPrivacyGateDropsSensitiveHistory() async throws {
        let fixture = makeFixture()
        let repository = fixture.repository
        var profile = try repository.ensureSelfProfile()
        profile.sensitiveBoundaries = [SensitiveBoundary(label: "medical", keywords: ["diagnosis"])]
        try repository.upsertSelfProfile(profile)

        let target = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Daily note",
                rawText: "I want to remember a quiet dinner.",
                captureSource: .manual
            )
        )
        let sensitive = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Private diagnosis",
                rawText: "This diagnosis detail should stay out of cloud evidence.",
                captureSource: .manual
            )
        )

        let pack = try await ContextPackBuilder(repository: repository).build(targetRecordID: target.id)

        XCTAssertFalse(pack.relatedMemories.contains { $0.recordID == sensitive.id })
        XCTAssertTrue(pack.privacyDecisions.contains { $0.sourceID == sensitive.id && $0.action == .drop })
        XCTAssertEqual(pack.budget.droppedByPrivacy, 1)
    }

    func testRankerGivesSemanticAndEntityEvidenceHigherScore() async throws {
        let fixture = makeFixture()
        let repository = fixture.repository
        let target = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Relationship planning",
                rawText: "I need to decide how to handle Alex and the project deadline.",
                mood: "stressed",
                captureSource: .manual
            )
        )
        let related = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex deadline",
                rawText: "Alex and I talked about the same project deadline and decision pressure.",
                mood: "stressed",
                captureSource: .manual
            )
        )
        let unrelated = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Coffee",
                rawText: "A quiet morning coffee with no project context.",
                mood: "calm",
                captureSource: .manual
            )
        )
        let profile = EntityProfile(
            entityID: UUID(),
            kind: .person,
            displayName: "Alex",
            confirmationState: .userConfirmed
        )
        let targetDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: target.id))
        let ranker = ContextRanker()

        let relatedScore = ranker.score(
            memory: related,
            target: targetDetail,
            query: target.record.rawText,
            semanticMemoryIDs: [related.id],
            profiles: [profile],
            selfProfile: try repository.ensureSelfProfile(),
            now: .now
        )
        let unrelatedScore = ranker.score(
            memory: unrelated,
            target: targetDetail,
            query: target.record.rawText,
            semanticMemoryIDs: [],
            profiles: [profile],
            selfProfile: try repository.ensureSelfProfile(),
            now: .now
        )

        XCTAssertGreaterThan(relatedScore.total, unrelatedScore.total)
        XCTAssertGreaterThan(relatedScore.semanticSimilarity, 0)
        XCTAssertGreaterThan(relatedScore.userConfirmedWeight, 0)
    }

    func testRankerPenalizesRepeatedRejectedSignals() async throws {
        let fixture = makeFixture()
        let repository = fixture.repository
        let target = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Work planning",
                rawText: "I need to decide how to handle the launch plan.",
                captureSource: .manual
            )
        )
        let rejected = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Coffee topic",
                rawText: "Coffee tasting notes that the user does not want tracked.",
                captureSource: .manual
            )
        )
        let correction = CorrectionEvent(
            kind: .doNotTrackTopic,
            actor: .user,
            targetRecordIDs: [rejected.id],
            sourceRecordIDs: [rejected.id],
            note: "coffee"
        )
        let targetDetail = try XCTUnwrap(repository.fetchMemoryDetail(recordID: target.id))

        let score = ContextRanker().score(
            memory: rejected,
            target: targetDetail,
            query: target.record.rawText,
            semanticMemoryIDs: [],
            profiles: [],
            selfProfile: try repository.ensureSelfProfile(),
            correctionEvents: [correction],
            now: .now
        )

        XCTAssertGreaterThan(score.repeatedRejectedSignalPenalty, 0)
    }

    private func makeFixture() -> AnalysisContextRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: AnalysisContextTestRecordAnalysisService()
        )
        return AnalysisContextRepositoryFixture(container: container, repository: repository)
    }
}

private struct AnalysisContextRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct AnalysisContextTestRecordAnalysisService: ReflectionAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: ["planning"],
            emotionInterpretation: record.userMood ?? "neutral",
            salienceScore: 0.7,
            retrievalTerms: ["planning", "decision", "Alex"],
            entityMentions: [EntityReference(kind: .person, name: "Alex", confidence: 0.8)],
            candidateEdges: [],
            followUpCandidates: [],
            reflectionHint: nil,
            createdAt: record.updatedAt
        )
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: "Context reflection",
            body: "Context reflection body.",
            evidenceSummary: "Context evidence",
            confidence: 0.6,
            sourceRecordIDs: [record.id],
            debugTrace: nil
        )
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        ReflectionServiceResult(
            title: reflection.title,
            body: reflection.body,
            evidenceSummary: reflection.evidenceSummary,
            confidence: reflection.confidence,
            sourceRecordIDs: reflection.sourceRecordIDs,
            debugTrace: nil
        )
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}

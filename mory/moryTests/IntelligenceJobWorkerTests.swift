import SwiftData
import XCTest
@testable import mory

@MainActor
final class IntelligenceJobWorkerTests: XCTestCase {
    func testWorkerExecutesExpandedJobKinds() async throws {
        let alexID = UUID()
        let fixture = makeRepositoryFixture(alexID: alexID)
        let repository = fixture.repository
        let seedFlagsTime = Date(timeIntervalSince1970: 1_800_600_000)

        try seedDisabledFlags(on: repository, now: seedFlagsTime)

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Career planning",
                rawText: "Met Alex to talk about my career transition.",
                captureSource: .composer,
                artifacts: [.text(title: "Career planning", body: "Met Alex to talk about my career transition.")]
            )
        )
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Resume update",
                rawText: "Updated my resume again during this career transition.",
                captureSource: .composer,
                artifacts: [.text(title: "Resume update", body: "Updated my resume again during this career transition.")]
            )
        )
        let third = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Next move",
                rawText: "Alex and I talked about the next chapter in work.",
                captureSource: .composer,
                artifacts: [.text(title: "Next move", body: "Alex and I talked about the next chapter in work.")]
            )
        )

        try await repository.refreshMemoryPipeline(recordID: first.id)
        try await repository.refreshMemoryPipeline(recordID: second.id)
        try await repository.refreshMemoryPipeline(recordID: third.id)

        let now = Date(timeIntervalSince1970: 1_800_600_600)
        try enableWorkerFeatures(on: repository, now: now)

        let personDetail = try XCTUnwrap(
            repository.fetchEntityDetails(kind: .person, limit: nil).first(where: { $0.entity.id == alexID })
        )
        try repository.upsertEntityProfile(
            EntityProfile(
                entityID: alexID,
                kind: .person,
                displayName: "Alex",
                mentionCount: 1,
                sourceRecordIDs: [first.id],
                confirmationState: .inferred,
                confidence: 0.7,
                createdAt: first.record.createdAt,
                updatedAt: first.record.updatedAt
            )
        )

        let entityJob = IntelligenceJob(
            kind: .entityEnrichment,
            targetType: .entity,
            targetID: alexID,
            status: .pending,
            priority: 0.9,
            scheduledAt: now.addingTimeInterval(-60),
            updatedAt: now.addingTimeInterval(-60)
        )
        let questionJob = IntelligenceJob(
            kind: .clarificationQuestionGeneration,
            targetType: .entity,
            targetID: alexID,
            status: .pending,
            priority: 0.8,
            scheduledAt: now.addingTimeInterval(-55),
            updatedAt: now.addingTimeInterval(-55)
        )
        let delta = GraphDelta(
            source: .userAnswer,
            operations: [
                GraphDeltaOperation(
                    kind: .setRelationship,
                    targetType: .entity,
                    targetID: alexID,
                    stringValue: EntityRelationshipToUser.friend.rawValue
                )
            ],
            confidence: 1,
            requiresUserConfirmation: false
        )
        try repository.upsertGraphDelta(delta)
        let graphDeltaJob = IntelligenceJob(
            kind: .graphDeltaApplication,
            targetType: .graphDelta,
            targetID: delta.id,
            status: .pending,
            priority: 0.7,
            scheduledAt: now.addingTimeInterval(-50),
            updatedAt: now.addingTimeInterval(-50)
        )
        let chapterJob = IntelligenceJob(
            kind: .chapterCandidate,
            targetType: .record,
            targetID: third.id,
            status: .pending,
            priority: 0.6,
            scheduledAt: now.addingTimeInterval(-45),
            updatedAt: now.addingTimeInterval(-45),
            requiresCloudAI: true
        )
        let personProfileJob = IntelligenceJob(
            kind: .personProfileRefresh,
            targetType: .entity,
            targetID: alexID,
            status: .pending,
            priority: 0.65,
            scheduledAt: now.addingTimeInterval(-40),
            updatedAt: now.addingTimeInterval(-40)
        )

        try repository.upsertIntelligenceJob(entityJob)
        try repository.upsertIntelligenceJob(questionJob)
        try repository.upsertIntelligenceJob(graphDeltaJob)
        try repository.upsertIntelligenceJob(chapterJob)
        try repository.upsertIntelligenceJob(personProfileJob)

        let worker = IntelligenceJobWorker()
        let report = await worker.processDueJobs(
            repository: repository,
            cloudIntelligenceService: WorkerMockCloudIntelligenceService(),
            now: now,
            limit: 8
        )

        XCTAssertEqual(Set(report.completedJobIDs), Set([
            entityJob.id,
            questionJob.id,
            graphDeltaJob.id,
            chapterJob.id,
            personProfileJob.id
        ]))
        XCTAssertTrue(report.failedJobIDs.isEmpty)
        XCTAssertTrue(report.unsupportedJobIDs.isEmpty)

        let updatedProfile = try XCTUnwrap(try repository.fetchEntityProfile(entityID: personDetail.id))
        XCTAssertEqual(updatedProfile.relationshipToUser, .friend)
        XCTAssertGreaterThanOrEqual(updatedProfile.mentionCount, 2)
        XCTAssertTrue(updatedProfile.sourceRecordIDs.contains(first.id))
        XCTAssertTrue(updatedProfile.sourceRecordIDs.contains(third.id))

        let personProfile = try XCTUnwrap(try repository.fetchPersonProfile(entityID: alexID))
        XCTAssertEqual(personProfile.displayName, "Alex")
        XCTAssertNotNil(personProfile.aiPortrait)
        XCTAssertTrue(personProfile.sourceRecordIDs.contains(first.id))
        XCTAssertTrue(personProfile.sourceRecordIDs.contains(third.id))

        let questions = try repository.fetchClarificationQuestions(status: .pending, limit: nil)
        XCTAssertTrue(questions.contains(where: {
            $0.kind == .entityRelationship && $0.targetID == alexID
        }))
        XCTAssertTrue(questions.contains(where: {
            $0.kind == .chapterCandidate
                && $0.targetID == third.id
                && $0.prompt.contains("Career Transition")
        }))

        let appliedDelta = try repository.fetchGraphDeltas(applied: true, limit: nil).first(where: { $0.id == delta.id })
        XCTAssertNotNil(appliedDelta)
    }

    private func makeRepositoryFixture(alexID: UUID) -> IntelligenceJobWorkerRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: WorkerRecordAnalysisService(alexID: alexID)
        )
        return IntelligenceJobWorkerRepositoryFixture(container: container, repository: repository)
    }

    private func seedDisabledFlags(
        on repository: MoryMemoryRepository,
        now: Date
    ) throws {
        var preferences = IntelligencePreferences.defaults
        preferences.localIntelligenceEnabled = true
        preferences.cloudIntelligenceEnabled = true
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = V6FeatureFlags.defaults
        flags.intelligenceJobs = false
        flags.entityProfiles = false
        flags.clarificationQuestions = false
        flags.cloudChapterSuggestions = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }

    private func enableWorkerFeatures(
        on repository: MoryMemoryRepository,
        now: Date
    ) throws {
        var preferences = try repository.fetchIntelligencePreferences()
        preferences.localIntelligenceEnabled = true
        preferences.cloudIntelligenceEnabled = true
        preferences.updatedAt = now
        try repository.saveIntelligencePreferences(preferences)

        var flags = try repository.fetchV6FeatureFlags()
        flags.intelligenceJobs = true
        flags.entityProfiles = true
        flags.clarificationQuestions = true
        flags.cloudChapterSuggestions = true
        flags.updatedAt = now
        try repository.saveV6FeatureFlags(flags)
    }
}

private struct IntelligenceJobWorkerRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct WorkerRecordAnalysisService: RecordAnalysisServing {
    let alexID: UUID

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        let lowercased = record.rawText.lowercased()
        let themes: [String]
        if lowercased.contains("career transition") || lowercased.contains("resume") || lowercased.contains("chapter in work") {
            themes = ["Career Transition"]
        } else {
            themes = ["Planning"]
        }

        let entityMentions: [EntityReference]
        if lowercased.contains("alex") {
            entityMentions = [
                EntityReference(
                    id: alexID,
                    kind: .person,
                    name: "Alex",
                    aliases: [],
                    confidence: 0.92
                )
            ]
        } else {
            entityMentions = []
        }

        return RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: themes,
            emotionInterpretation: "",
            salienceScore: 0.74,
            retrievalTerms: themes,
            entityMentions: entityMentions,
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
        throw WorkerTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw WorkerTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}

private struct WorkerMockCloudIntelligenceService: CloudIntelligenceServing {
    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw WorkerTestError.unsupported
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw WorkerTestError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        MoryAPIClient.ChapterSuggestionResponse(
            schemaVersion: 1,
            chapterCandidates: [
                .init(
                    title: "Career Transition",
                    summary: "A work transition chapter is taking shape.",
                    evidenceRecordIDs: payload.evidenceSnippets.compactMap(\.recordID),
                    confidence: 0.83,
                    requiresConfirmation: true
                )
            ],
            meta: nil
        )
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw WorkerTestError.unsupported
    }

    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse {
        throw WorkerTestError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw WorkerTestError.unsupported
    }
}

private enum WorkerTestError: Error {
    case unsupported
}

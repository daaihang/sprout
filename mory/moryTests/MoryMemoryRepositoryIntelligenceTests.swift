import SwiftData
import XCTest
@testable import mory

@MainActor
final class MoryMemoryRepositoryIntelligenceTests: XCTestCase {
    func testSchemaOpensWithV6IntelligenceStores() throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        XCTAssertNotNil(container.mainContext)
    }

    func testIntelligencePreferencesAndFeatureFlagsPersistAndSurviveLocalDataClear() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository

        var preferences = try repository.fetchIntelligencePreferences()
        preferences.cloudIntelligenceEnabled = true
        preferences.voiceRefinementEnabled = true
        preferences.dailyQuestionsEnabled = true
        preferences.notificationPreferences.enabled = true
        preferences.updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try repository.saveIntelligencePreferences(preferences)

        var flags = try repository.fetchV6FeatureFlags()
        flags.intelligenceJobs = true
        flags.entityProfiles = true
        flags.clarificationQuestions = true
        flags.updatedAt = Date(timeIntervalSince1970: 1_800_000_001)
        try repository.saveV6FeatureFlags(flags)

        XCTAssertTrue(try repository.fetchIntelligencePreferences().cloudIntelligenceEnabled)
        XCTAssertTrue(try repository.fetchIntelligencePreferences().notificationPreferences.enabled)
        XCTAssertTrue(try repository.fetchV6FeatureFlags().intelligenceJobs)
        XCTAssertTrue(try repository.fetchV6FeatureFlags().clarificationQuestions)

        try repository.clearAllLocalData()

        XCTAssertTrue(try repository.fetchIntelligencePreferences().cloudIntelligenceEnabled)
        XCTAssertTrue(try repository.fetchV6FeatureFlags().entityProfiles)
    }

    func testEntityProfileRoundTripAndUpsertByEntityID() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let entityID = UUID()
        let recordID = UUID()
        var profile = EntityProfile(
            entityID: entityID,
            kind: .person,
            displayName: "Alex",
            aliases: ["A. Chen"],
            relationshipToUser: .coworker,
            mentionCount: 3,
            sourceRecordIDs: [recordID],
            confirmationState: .userConfirmed,
            confidence: 0.92
        )
        try repository.upsertEntityProfile(profile)

        var stored = try XCTUnwrap(repository.fetchEntityProfile(entityID: entityID))
        XCTAssertEqual(stored.displayName, "Alex")
        XCTAssertEqual(stored.relationshipToUser, .coworker)
        XCTAssertEqual(stored.sourceRecordIDs, [recordID])

        profile.displayName = "Alex Chen"
        profile.aliases.append("Alex")
        try repository.upsertEntityProfile(profile)

        stored = try XCTUnwrap(repository.fetchEntityProfile(entityID: entityID))
        XCTAssertEqual(stored.displayName, "Alex Chen")
        XCTAssertEqual(stored.aliases, ["A. Chen", "Alex"])
        XCTAssertEqual(try repository.fetchEntityProfiles(kind: .person, limit: nil).count, 1)
    }

    func testClarificationQuestionCanBeAnsweredAndDismissed() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let question = ClarificationQuestion(
            kind: .entityRelationship,
            prompt: "Who is Alex to you?",
            targetType: .entity,
            targetID: UUID(),
            candidateAnswers: [ClarificationAnswerOption(label: "Coworker", value: EntityRelationshipToUser.coworker.rawValue)],
            priority: 0.9,
            reason: "Alex appeared in recent memories."
        )
        try repository.upsertClarificationQuestion(question)

        XCTAssertEqual(try repository.fetchClarificationQuestions(status: .pending, limit: nil).count, 1)

        let answer = ClarificationAnswer(value: EntityRelationshipToUser.coworker.rawValue, answeredAt: Date(timeIntervalSince1970: 1_800_000_002))
        try repository.answerClarificationQuestion(question.id, answer: answer)

        let answered = try XCTUnwrap(repository.fetchClarificationQuestions(status: .answered, limit: nil).first)
        XCTAssertEqual(answered.answer?.value, EntityRelationshipToUser.coworker.rawValue)
        XCTAssertEqual(answered.answeredAt, answer.answeredAt)

        var second = question
        second = ClarificationQuestion(
            id: UUID(),
            kind: second.kind,
            prompt: second.prompt,
            targetType: second.targetType,
            targetID: second.targetID,
            priority: 0.7,
            reason: second.reason
        )
        try repository.upsertClarificationQuestion(second)
        try repository.dismissClarificationQuestion(second.id)

        let dismissed = try XCTUnwrap(repository.fetchClarificationQuestions(status: .dismissed, limit: nil).first)
        XCTAssertEqual(dismissed.id, second.id)
        XCTAssertNotNil(dismissed.dismissedAt)
    }

    func testIntelligenceJobsAndGraphDeltasRoundTripAndClear() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let targetID = UUID()
        let job = IntelligenceJob(
            kind: .entityEnrichment,
            targetType: .entity,
            targetID: targetID,
            priority: 0.6,
            requiresCloudAI: false
        )
        try repository.upsertIntelligenceJob(job)

        XCTAssertEqual(try repository.fetchIntelligenceJobs(status: .pending, limit: nil).first?.dedupeKey, job.dedupeKey)

        let delta = GraphDelta(
            source: .userAnswer,
            operations: [
                GraphDeltaOperation(
                    kind: .setRelationship,
                    targetType: .entity,
                    targetID: targetID,
                    stringValue: EntityRelationshipToUser.friend.rawValue
                )
            ],
            confidence: 1,
            requiresUserConfirmation: false
        )
        try repository.upsertGraphDelta(delta)
        XCTAssertEqual(try repository.fetchGraphDeltas(applied: false, limit: nil).count, 1)

        let appliedAt = Date(timeIntervalSince1970: 1_800_000_003)
        try repository.markGraphDeltaApplied(delta.id, appliedAt: appliedAt)
        XCTAssertEqual(try repository.fetchGraphDeltas(applied: true, limit: nil).first?.appliedAt, appliedAt)

        try repository.clearAllLocalData()
        XCTAssertTrue(try repository.fetchIntelligenceJobs(status: nil, limit: nil).isEmpty)
        XCTAssertTrue(try repository.fetchGraphDeltas(applied: nil, limit: nil).isEmpty)
    }

    func testDeleteMemoryPurgesOrphanedV6StateAndRetainsConfirmedProfiles() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let context = fixture.container.mainContext

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning sync",
                rawText: "Met Alex to sort out launch planning and clarify ownership.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning sync", body: "Met Alex to sort out launch planning and clarify ownership.")]
            )
        )
        let recordID = memory.record.id
        let artifactIDs = try repository.fetchArtifacts(recordID: recordID).map(\.id)
        let firstArtifactID = try XCTUnwrap(artifactIDs.first)

        let inferredEntityID = UUID()
        let retainedEntityID = UUID()
        let questionID = UUID()
        let graphDeltaID = UUID()

        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: inferredEntityID,
                    kind: .person,
                    displayName: "Alex",
                    mentionCount: 1,
                    sourceRecordIDs: [recordID],
                    confirmationState: .inferred
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: retainedEntityID,
                    kind: .person,
                    displayName: "Jamie",
                    aliases: ["J"],
                    relationshipToUser: .friend,
                    mentionCount: 2,
                    sourceRecordIDs: [recordID],
                    confirmationState: .userConfirmed
                )
            )
        )
        context.insert(
            ClarificationQuestionStore(
                domainModel: ClarificationQuestion(
                    id: questionID,
                    kind: .entityRelationship,
                    prompt: "Who is Alex to you?",
                    targetType: .entity,
                    targetID: inferredEntityID,
                    sourceRecordIDs: [recordID],
                    sourceArtifactIDs: artifactIDs,
                    priority: 0.9,
                    reason: "Alex was mentioned in a recent memory."
                )
            )
        )
        context.insert(
            GraphDeltaStore(
                domainModel: GraphDelta(
                    id: graphDeltaID,
                    source: .userAnswer,
                    operations: [
                        GraphDeltaOperation(
                            kind: .addAlias,
                            targetType: .artifact,
                            targetID: firstArtifactID,
                            stringValue: "Alex"
                        )
                    ],
                    confidence: 0.95,
                    requiresUserConfirmation: false
                )
            )
        )
        context.insert(
            IntelligenceJobStore(
                domainModel: IntelligenceJob(
                    kind: .postAnalysis,
                    targetType: .record,
                    targetID: recordID,
                    priority: 0.4
                )
            )
        )
        context.insert(
            IntelligenceJobStore(
                domainModel: IntelligenceJob(
                    kind: .graphDeltaApplication,
                    targetType: .graphDelta,
                    targetID: graphDeltaID,
                    priority: 0.5
                )
            )
        )
        context.insert(
            HomeBoardSignalStore(
                domainModel: HomeBoardSignal(
                    kind: .clarificationQuestion,
                    targetType: .entity,
                    targetID: inferredEntityID,
                    sourceRecordIDs: [recordID],
                    title: "Clarify Alex",
                    subtitle: "We need one more detail.",
                    priority: 0.8,
                    reason: "This person may matter later."
                )
            )
        )
        context.insert(
            NotificationIntentStore(
                domainModel: NotificationIntent(
                    kind: .backgroundDone,
                    title: "Processing ready",
                    body: "Planning sync is ready for review.",
                    targetType: .record,
                    targetID: recordID,
                    scheduledAt: .now
                )
            )
        )
        try context.save()

        try repository.deleteMemory(recordID: recordID)

        XCTAssertTrue(try context.fetch(FetchDescriptor<ClarificationQuestionStore>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<GraphDeltaStore>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<IntelligenceJobStore>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<HomeBoardSignalStore>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<NotificationIntentStore>()).isEmpty)

        let remainingProfiles = try context.fetch(FetchDescriptor<EntityProfileStore>())
        XCTAssertEqual(remainingProfiles.count, 1)
        XCTAssertEqual(remainingProfiles.first?.entityID, retainedEntityID)
        XCTAssertEqual(remainingProfiles.first?.sourceRecordIDs, [])
        XCTAssertEqual(remainingProfiles.first?.relationshipToUserRawValue, EntityRelationshipToUser.friend.rawValue)
    }

    func testRefreshMemoryPipelineCreatesPersonProfileQuestionAndHomeCard() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex planning sync",
                rawText: "Met Alex to plan the public beta rollout.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex planning sync", body: "Met Alex to plan the public beta rollout.")]
            )
        )

        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let profile = try XCTUnwrap(try repository.fetchEntityProfiles(kind: .person, limit: nil).first)
        XCTAssertEqual(profile.displayName, "Alex")
        XCTAssertEqual(profile.sourceRecordIDs, [memory.record.id])
        XCTAssertEqual(profile.commonContextLabels, ["planning"])

        let question = try XCTUnwrap(try repository.fetchClarificationQuestions(status: .pending, limit: nil).first)
        XCTAssertEqual(question.kind, .entityRelationship)
        XCTAssertEqual(question.targetID, profile.entityID)
        XCTAssertEqual(question.sourceRecordIDs, [memory.record.id])

        let home = try repository.fetchHomeBoard(for: .now, limit: 8)
        XCTAssertTrue(home.items.contains { item in
            if case let .clarificationQuestion(homeQuestion, homeProfile) = item.renderValue {
                return homeQuestion.id == question.id && homeProfile?.entityID == profile.entityID
            }
            return false
        })

        let detail = try XCTUnwrap(repository.fetchEntityDetail(entityID: profile.entityID))
        XCTAssertEqual(detail.intelligenceProfile?.entityID, profile.entityID)
        XCTAssertEqual(detail.pendingQuestions.first?.id, question.id)
    }

    func testKnownPersonDoesNotSpamDuplicatePendingQuestion() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex one",
                rawText: "Met Alex after lunch.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex one", body: "Met Alex after lunch.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.record.id)

        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex two",
                rawText: "Alex came up again while we planned the launch.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex two", body: "Alex came up again while we planned the launch.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.record.id)

        let profiles = try repository.fetchEntityProfiles(kind: .person, limit: nil)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.sourceRecordIDs.count, 2)

        let pendingQuestions = try repository.fetchClarificationQuestions(status: .pending, limit: nil)
        XCTAssertEqual(pendingQuestions.count, 1)
        XCTAssertEqual(pendingQuestions.first?.kind, .entityRelationship)
    }

    func testAnswerClarificationQuestionAppliesGraphDeltaAndRemovesHomeCard() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex follow-up",
                rawText: "Alex helped untangle the beta launch checklist.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex follow-up", body: "Alex helped untangle the beta launch checklist.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.record.id)

        let question = try XCTUnwrap(try repository.fetchClarificationQuestions(status: .pending, limit: nil).first)
        try repository.answerClarificationQuestion(
            question.id,
            answer: ClarificationAnswer(value: EntityRelationshipToUser.friend.rawValue)
        )

        XCTAssertTrue(try repository.fetchClarificationQuestions(status: .pending, limit: nil).isEmpty)
        let updatedProfile = try XCTUnwrap(try repository.fetchEntityProfile(entityID: question.targetID))
        XCTAssertEqual(updatedProfile.relationshipToUser, .friend)
        XCTAssertEqual(updatedProfile.confirmationState, .userConfirmed)

        let appliedDelta = try XCTUnwrap(try repository.fetchGraphDeltas(applied: true, limit: nil).first)
        XCTAssertEqual(appliedDelta.operations.first?.kind, .setRelationship)
        XCTAssertEqual(appliedDelta.operations.first?.targetID, question.targetID)

        let home = try repository.fetchHomeBoard(for: .now, limit: 8)
        XCTAssertFalse(home.items.contains { item in
            if case let .clarificationQuestion(homeQuestion, _) = item.renderValue {
                return homeQuestion.targetID == question.targetID
            }
            return false
        })

        let detail = try XCTUnwrap(repository.fetchEntityDetail(entityID: question.targetID))
        XCTAssertEqual(detail.intelligenceProfile?.relationshipToUser, .friend)
        XCTAssertTrue(detail.pendingQuestions.isEmpty)
    }

    private func makeRepositoryFixture() -> RepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: IntelligenceTestRecordAnalysisService()
        )
        return RepositoryFixture(container: container, repository: repository)
    }

    private func enablePhase2Loop(on repository: MoryMemoryRepository) throws {
        var preferences = try repository.fetchIntelligencePreferences()
        preferences.localIntelligenceEnabled = true
        preferences.homeSuggestionsEnabled = true
        preferences.updatedAt = .now
        try repository.saveIntelligencePreferences(preferences)

        var flags = try repository.fetchV6FeatureFlags()
        flags.intelligenceJobs = true
        flags.entityProfiles = true
        flags.clarificationQuestions = true
        flags.updatedAt = .now
        try repository.saveV6FeatureFlags(flags)
    }
}

private struct RepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct IntelligenceTestRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Intelligence test summary",
            themes: ["planning"],
            emotionInterpretation: "steady",
            salienceScore: 0.7,
            retrievalTerms: ["planning"],
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
            title: "Reflection",
            body: "Reflection body with enough detail for tests.",
            evidenceSummary: "Evidence",
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

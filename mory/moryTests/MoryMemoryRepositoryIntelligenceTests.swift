import SwiftData
import XCTest
@testable import mory

@MainActor
final class MoryMemoryRepositoryIntelligenceTests: XCTestCase {
    func testSchemaOpensWithV6IntelligenceStores() throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        XCTAssertNotNil(container.mainContext)
    }

    func testSelfProfileRoundTripAndDefaultCreation() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository

        XCTAssertNil(try repository.fetchSelfProfile())

        var profile = try repository.ensureSelfProfile()
        XCTAssertEqual(profile.syncKey, SelfProfile.defaultSyncKey)
        XCTAssertTrue(profile.aliases.contains("我"))

        profile.displayName = "Mory Tester"
        profile.aliases.append("tester")
        profile.lifeRoles = [SelfRole(label: "founder", detail: "building Mory", confidence: 1)]
        profile.longTermGoals = [SelfGoal(title: "ship v7", status: "active")]
        profile.preferences = [SelfPreference(key: "questionTone", value: "direct")]
        profile.sensitiveBoundaries = [SensitiveBoundary(label: "health", keywords: ["medical"])]
        profile.expressionPatterns = [ExpressionPattern(phrase: "I am done", interpretation: "may be venting", confidence: 0.7)]
        profile.updatedAt = Date(timeIntervalSince1970: 1_900_000_000)
        try repository.upsertSelfProfile(profile)

        let stored = try XCTUnwrap(repository.fetchSelfProfile())
        XCTAssertEqual(stored.displayName, "Mory Tester")
        XCTAssertEqual(stored.aliases.last, "tester")
        XCTAssertEqual(stored.lifeRoles.first?.label, "founder")
        XCTAssertEqual(stored.longTermGoals.first?.title, "ship v7")
        XCTAssertEqual(stored.preferences.first?.value, "direct")
        XCTAssertEqual(stored.sensitiveBoundaries.first?.keywords, ["medical"])
        XCTAssertEqual(stored.expressionPatterns.first?.interpretation, "may be venting")

        let ensuredAgain = try repository.ensureSelfProfile()
        XCTAssertEqual(ensuredAgain.id, stored.id)
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

        try repository.rejectGraphDelta(delta.id, note: "Not this relationship.")
        let rejection = try XCTUnwrap(try repository.fetchCorrectionEvents(kind: .graphDeltaRejected, limit: nil).first)
        XCTAssertEqual(rejection.metadata["graphDeltaID"], delta.id.uuidString)
        XCTAssertEqual(rejection.note, "Not this relationship.")

        try repository.reverseCorrectionEvent(rejection.id, reversedAt: Date(timeIntervalSince1970: 1_800_000_002))
        let reversed = try XCTUnwrap(try repository.fetchCorrectionEvents(kind: .graphDeltaRejected, limit: nil).first)
        XCTAssertNotNil(reversed.reversedAt)

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
                    kind: .analysisReady,
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

    func testMergePersonEntitiesRewritesGraphReferencesAndRecordsTombstone() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let context = fixture.container.mainContext

        let primaryID = UUID()
        let mergingID = UUID()
        let relatedID = UUID()
        let recordA = UUID()
        let recordB = UUID()
        let artifactA = UUID()
        let artifactB = UUID()

        context.insert(
            EntityNodeStore(
                domainModel: EntityNode(
                    id: primaryID,
                    kind: .person,
                    displayName: "Alex",
                    aliases: ["A"],
                    summary: "",
                    provenanceRecordIDs: [recordA],
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            EntityNodeStore(
                domainModel: EntityNode(
                    id: mergingID,
                    kind: .person,
                    displayName: "Alexander Chen",
                    aliases: ["Alex Chen"],
                    summary: "",
                    provenanceRecordIDs: [recordB],
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: primaryID,
                    kind: .person,
                    displayName: "Alex",
                    aliases: ["A"],
                    mentionCount: 2,
                    sourceRecordIDs: [recordA],
                    confirmationState: .userConfirmed
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: mergingID,
                    kind: .person,
                    displayName: "Alexander Chen",
                    aliases: ["Alex Chen"],
                    mentionCount: 1,
                    sourceRecordIDs: [recordB]
                )
            )
        )
        context.insert(
            ArtifactEntityLinkStore(
                domainModel: ArtifactEntityLink(
                    artifactID: artifactA,
                    entityID: primaryID,
                    source: "analysis",
                    sourceRecordID: recordA,
                    createdAt: .now
                )
            )
        )
        context.insert(
            ArtifactEntityLinkStore(
                domainModel: ArtifactEntityLink(
                    artifactID: artifactB,
                    entityID: mergingID,
                    source: "analysis",
                    sourceRecordID: recordB,
                    createdAt: .now
                )
            )
        )
        context.insert(
            EntityEdgeStore(
                domainModel: EntityEdge(
                    fromEntityID: mergingID,
                    toEntityID: relatedID,
                    relationKind: .mentionedWith,
                    firstSeenAt: .now,
                    lastSeenAt: .now,
                    sourceArtifactIDs: [artifactB],
                    sourceRecordIDs: [recordB]
                )
            )
        )
        context.insert(
            TemporalArcStore(
                domainModel: TemporalArc(
                    title: "Alex rollout arc",
                    summary: "arc",
                    status: .accepted,
                    sourceRecordIDs: [recordB],
                    sourceArtifactIDs: [artifactB],
                    sourceEntityIDs: [mergingID],
                    startDate: .now,
                    endDate: .now,
                    intensityScore: 0.6,
                    clusterStrength: 0.6,
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            ReflectionSnapshotStore(
                domainModel: ReflectionSnapshot(
                    type: .relationship,
                    title: "People reflection",
                    body: "body",
                    evidenceSummary: "evidence",
                    confidence: 0.7,
                    status: .suggested,
                    sourceRecordIDs: [recordB],
                    sourceArtifactIDs: [artifactB],
                    sourceEntityIDs: [mergingID],
                    createdAt: .now
                )
            )
        )
        context.insert(
            ClarificationQuestionStore(
                domainModel: ClarificationQuestion(
                    kind: .entityRelationship,
                    prompt: "Who is Alexander Chen?",
                    targetType: .entity,
                    targetID: mergingID,
                    sourceRecordIDs: [recordB],
                    priority: 0.7,
                    reason: "Need relation."
                )
            )
        )
        context.insert(
            HomeBoardSignalStore(
                domainModel: HomeBoardSignal(
                    kind: .clarificationQuestion,
                    targetType: .entity,
                    targetID: mergingID,
                    sourceRecordIDs: [recordB],
                    title: "Question",
                    subtitle: "subtitle",
                    priority: 0.5,
                    reason: "reason"
                )
            )
        )
        context.insert(
            NotificationIntentStore(
                domainModel: NotificationIntent(
                    kind: .dailyQuestion,
                    title: "Question",
                    body: "Body",
                    targetType: .entity,
                    targetID: mergingID,
                    scheduledAt: .now
                )
            )
        )
        try context.save()

        let merged = try repository.mergePersonEntities(
            primaryID: primaryID,
            mergingIDs: [mergingID],
            displayName: "Alex Chen"
        )

        XCTAssertEqual(merged.entityID, primaryID)
        XCTAssertEqual(merged.displayName, "Alex Chen")
        XCTAssertTrue(merged.aliases.contains("Alexander Chen"))

        XCTAssertNil(try repository.fetchEntityDetail(entityID: mergingID))
        let links = try context.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        XCTAssertFalse(links.contains { $0.entityID == mergingID })

        let arcs = try context.fetch(FetchDescriptor<TemporalArcStore>())
        XCTAssertTrue(arcs.allSatisfy { !$0.sourceEntityIDs.contains(mergingID) })
        XCTAssertTrue(arcs.contains { $0.sourceEntityIDs.contains(primaryID) })

        let reflections = try context.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        XCTAssertTrue(reflections.allSatisfy { !$0.sourceEntityIDs.contains(mergingID) })

        let questions = try context.fetch(FetchDescriptor<ClarificationQuestionStore>())
        XCTAssertTrue(questions.allSatisfy { $0.targetID == primaryID })

        let intents = try context.fetch(FetchDescriptor<NotificationIntentStore>())
        XCTAssertTrue(intents.allSatisfy { $0.targetID == primaryID })

        let tombstones = try repository.fetchEntityTombstones(limit: nil)
        XCTAssertTrue(tombstones.contains { $0.oldEntityID == mergingID && $0.replacementEntityID == primaryID })

        let corrections = try repository.fetchCorrectionEvents(kind: .sameEntity, limit: nil)
        XCTAssertTrue(corrections.contains { Set($0.targetEntityIDs) == Set([primaryID, mergingID]) && $0.isReversible })

        let jobs = try repository.fetchIntelligenceJobs(status: .pending, limit: nil)
        XCTAssertTrue(jobs.contains { $0.kind == .entityEnrichment && $0.targetID == primaryID })
        XCTAssertTrue(jobs.contains { $0.kind == .chapterCandidate && $0.targetID == recordA })
        XCTAssertTrue(jobs.contains { $0.kind == .chapterCandidate && $0.targetID == recordB })
    }

    func testDeletingMergedSurvivorClearsTombstoneReplacement() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let context = fixture.container.mainContext

        let primaryID = UUID()
        let mergingID = UUID()
        let recordA = UUID()
        let recordB = UUID()

        context.insert(
            EntityNodeStore(
                domainModel: EntityNode(
                    id: primaryID,
                    kind: .person,
                    displayName: "Alex",
                    aliases: [],
                    summary: "",
                    provenanceRecordIDs: [recordB],
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            EntityNodeStore(
                domainModel: EntityNode(
                    id: mergingID,
                    kind: .person,
                    displayName: "Alexander",
                    aliases: [],
                    summary: "",
                    provenanceRecordIDs: [recordA],
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: primaryID,
                    kind: .person,
                    displayName: "Alex",
                    sourceRecordIDs: [recordB],
                    confirmationState: .userConfirmed
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: mergingID,
                    kind: .person,
                    displayName: "Alexander",
                    sourceRecordIDs: [recordA],
                    confirmationState: .userConfirmed
                )
            )
        )
        try context.save()

        _ = try repository.mergePersonEntities(primaryID: primaryID, mergingIDs: [mergingID], displayName: nil)
        XCTAssertTrue(try repository.fetchEntityTombstones(limit: nil).contains {
            $0.oldEntityID == mergingID && $0.replacementEntityID == primaryID
        })

        try repository.deleteMemory(recordID: recordA)
        try repository.deleteMemory(recordID: recordB)

        let tombstones = try repository.fetchEntityTombstones(limit: nil)
        let mergedTombstone = try XCTUnwrap(tombstones.first { $0.oldEntityID == mergingID })
        XCTAssertNil(mergedTombstone.replacementEntityID)
        XCTAssertTrue(mergedTombstone.note?.contains("Replacement entity was deleted.") == true)
        XCTAssertTrue(tombstones.contains { $0.oldEntityID == primaryID && $0.reason == .deleted })
    }

    func testSplitPersonEntityRewritesLinksAndCreatesCorrectionEvent() throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let context = fixture.container.mainContext

        let entityID = UUID()
        let relatedID = UUID()
        let recordA = UUID()
        let recordB = UUID()
        let artifactA = UUID()
        let artifactB = UUID()

        context.insert(
            EntityNodeStore(
                domainModel: EntityNode(
                    id: entityID,
                    kind: .person,
                    displayName: "舍友",
                    aliases: [],
                    summary: "",
                    provenanceRecordIDs: [recordA, recordB],
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            EntityProfileStore(
                domainModel: EntityProfile(
                    entityID: entityID,
                    kind: .person,
                    displayName: "舍友",
                    mentionCount: 2,
                    sourceRecordIDs: [recordA, recordB],
                    confirmationState: .userConfirmed
                )
            )
        )
        context.insert(
            ArtifactEntityLinkStore(
                domainModel: ArtifactEntityLink(
                    artifactID: artifactA,
                    entityID: entityID,
                    source: "analysis",
                    sourceRecordID: recordA,
                    createdAt: .now
                )
            )
        )
        context.insert(
            ArtifactEntityLinkStore(
                domainModel: ArtifactEntityLink(
                    artifactID: artifactB,
                    entityID: entityID,
                    source: "analysis",
                    sourceRecordID: recordB,
                    createdAt: .now
                )
            )
        )
        context.insert(
            EntityEdgeStore(
                domainModel: EntityEdge(
                    fromEntityID: entityID,
                    toEntityID: relatedID,
                    relationKind: .mentionedWith,
                    firstSeenAt: .now,
                    lastSeenAt: .now,
                    sourceArtifactIDs: [artifactA, artifactB],
                    sourceRecordIDs: [recordA, recordB]
                )
            )
        )
        context.insert(
            TemporalArcStore(
                domainModel: TemporalArc(
                    title: "Roommate arc",
                    summary: "arc",
                    status: .accepted,
                    sourceRecordIDs: [recordA, recordB],
                    sourceArtifactIDs: [artifactA, artifactB],
                    sourceEntityIDs: [entityID],
                    startDate: .now,
                    endDate: .now,
                    intensityScore: 0.8,
                    clusterStrength: 0.7,
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        )
        context.insert(
            ReflectionSnapshotStore(
                domainModel: ReflectionSnapshot(
                    type: .relationship,
                    title: "Roommate reflection",
                    body: "body",
                    evidenceSummary: "evidence",
                    confidence: 0.6,
                    status: .suggested,
                    sourceRecordIDs: [recordA, recordB],
                    sourceArtifactIDs: [artifactA, artifactB],
                    sourceEntityIDs: [entityID],
                    createdAt: .now
                )
            )
        )
        context.insert(
            ClarificationQuestionStore(
                domainModel: ClarificationQuestion(
                    kind: .entityRelationship,
                    prompt: "Who is this roommate?",
                    targetType: .entity,
                    targetID: entityID,
                    sourceRecordIDs: [recordA],
                    priority: 0.6,
                    reason: "Need clarification."
                )
            )
        )
        context.insert(
            HomeBoardSignalStore(
                domainModel: HomeBoardSignal(
                    kind: .clarificationQuestion,
                    targetType: .entity,
                    targetID: entityID,
                    sourceRecordIDs: [recordA],
                    title: "Clarify roommate",
                    subtitle: "Who is this?",
                    priority: 0.6,
                    reason: "role split"
                )
            )
        )
        try context.save()

        let newProfile = try repository.splitPersonEntity(
            id: entityID,
            movingRecordIDs: [recordA],
            displayName: "Lily",
            aliases: ["舍友A"]
        )

        XCTAssertEqual(newProfile.displayName, "Lily")
        XCTAssertEqual(Set(newProfile.sourceRecordIDs), Set([recordA]))

        let original = try XCTUnwrap(try repository.fetchEntityProfile(entityID: entityID))
        XCTAssertEqual(Set(original.sourceRecordIDs), Set([recordB]))

        let links = try context.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        XCTAssertTrue(links.contains { $0.sourceRecordID == recordA && $0.entityID == newProfile.entityID })
        XCTAssertTrue(links.contains { $0.sourceRecordID == recordB && $0.entityID == entityID })

        let edges = try context.fetch(FetchDescriptor<EntityEdgeStore>()).map(\.domainModel)
        XCTAssertTrue(edges.contains { $0.fromEntityID == newProfile.entityID || $0.toEntityID == newProfile.entityID })
        XCTAssertTrue(edges.contains { $0.fromEntityID == entityID || $0.toEntityID == entityID })

        let questions = try context.fetch(FetchDescriptor<ClarificationQuestionStore>())
        XCTAssertTrue(questions.contains { $0.sourceRecordIDs == [recordA] && $0.targetID == newProfile.entityID })

        let signals = try context.fetch(FetchDescriptor<HomeBoardSignalStore>())
        XCTAssertTrue(signals.contains { $0.sourceRecordIDs == [recordA] && $0.targetID == newProfile.entityID })

        let arcs = try context.fetch(FetchDescriptor<TemporalArcStore>())
        XCTAssertTrue(arcs.allSatisfy { $0.sourceEntityIDs.contains(entityID) && $0.sourceEntityIDs.contains(newProfile.entityID) })

        let reflections = try context.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        XCTAssertTrue(reflections.allSatisfy { $0.sourceEntityIDs.contains(entityID) && $0.sourceEntityIDs.contains(newProfile.entityID) })

        let corrections = try repository.fetchCorrectionEvents(kind: .splitEntity, limit: nil)
        XCTAssertTrue(corrections.contains { Set($0.targetEntityIDs) == Set([entityID, newProfile.entityID]) && $0.isReversible })

        let jobs = try repository.fetchIntelligenceJobs(status: .pending, limit: nil)
        XCTAssertTrue(jobs.contains { $0.kind == .entityEnrichment && $0.targetID == entityID })
        XCTAssertTrue(jobs.contains { $0.kind == .entityEnrichment && $0.targetID == newProfile.entityID })
        XCTAssertTrue(jobs.contains { $0.kind == .chapterCandidate && $0.targetID == recordA })
        XCTAssertTrue(jobs.contains { $0.kind == .chapterCandidate && $0.targetID == recordB })
    }

    func testPersonProfileRefreshBuildsEvidenceBackedPortraitAfterNewMemories() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Planning with Alex",
                rawText: "Met Alex to talk through product planning.",
                captureSource: .composer,
                artifacts: [.text(title: "Planning with Alex", body: "Met Alex to talk through product planning.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.id)

        let initialProfile = try XCTUnwrap(try repository.fetchPersonProfiles(limit: nil).first)
        XCTAssertEqual(initialProfile.displayName, "Alex")
        XCTAssertNotNil(initialProfile.aiPortrait)
        XCTAssertTrue(initialProfile.sourceRecordIDs.contains(first.id))
        XCTAssertFalse(initialProfile.fieldEvidence.isEmpty)

        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex follow-up",
                rawText: "Alex and I revisited launch planning after the first sync.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex follow-up", body: "Alex and I revisited launch planning after the first sync.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: second.id)

        let refreshed = try XCTUnwrap(try repository.fetchPersonProfile(entityID: initialProfile.entityID))
        XCTAssertTrue(refreshed.sourceRecordIDs.contains(first.id))
        XCTAssertTrue(refreshed.sourceRecordIDs.contains(second.id))
        XCTAssertTrue(refreshed.aiPortrait?.summary.contains("memories") == true)
        XCTAssertGreaterThan(refreshed.importanceScore ?? 0, initialProfile.importanceScore ?? 0)
    }

    func testPersonProfileUserConfirmedRelationshipSurvivesRefresh() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex sync",
                rawText: "Met Alex for planning.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex sync", body: "Met Alex for planning.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: memory.id)

        let profile = try XCTUnwrap(try repository.fetchPersonProfiles(limit: nil).first)
        _ = try repository.applyPersonProfileMutation(
            PersonProfileMutation(
                entityID: profile.entityID,
                field: .relationshipToUser,
                relationshipValue: .friend,
                note: "Alex is a friend."
            )
        )

        var entityProfile = try XCTUnwrap(try repository.fetchEntityProfile(entityID: profile.entityID))
        entityProfile.relationshipToUser = .coworker
        entityProfile.updatedAt = .now
        try repository.upsertEntityProfile(entityProfile)

        let refreshed = try XCTUnwrap(try repository.refreshPersonProfile(entityID: profile.entityID, now: .now))
        XCTAssertEqual(refreshed.relationshipToUser, .friend)
        XCTAssertTrue(refreshed.relationshipHistory.contains { $0.status == .userConfirmed && $0.relationship == .friend })
        XCTAssertTrue(refreshed.fieldEvidence.contains { $0.source == .userEdit && $0.status == .userConfirmed })
    }

    func testDeleteMemoryInvalidatesPersonProfileFieldEvidence() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        try enablePhase2Loop(on: repository)

        let first = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex first",
                rawText: "Alex helped with planning.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex first", body: "Alex helped with planning.")]
            )
        )
        let second = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Alex second",
                rawText: "Alex discussed planning again.",
                captureSource: .composer,
                artifacts: [.text(title: "Alex second", body: "Alex discussed planning again.")]
            )
        )
        try await repository.refreshMemoryPipeline(recordID: first.id)
        try await repository.refreshMemoryPipeline(recordID: second.id)

        let profile = try XCTUnwrap(try repository.fetchPersonProfiles(limit: nil).first)
        XCTAssertTrue(profile.fieldEvidence.contains { $0.sourceRecordIDs.contains(first.id) })

        try repository.deleteMemory(recordID: first.id)

        let retained = try XCTUnwrap(try repository.fetchPersonProfile(entityID: profile.entityID))
        XCTAssertFalse(retained.sourceRecordIDs.contains(first.id))
        XCTAssertFalse(retained.fieldEvidence.contains { $0.sourceRecordIDs.contains(first.id) })
        XCTAssertTrue(retained.fieldEvidence.contains { $0.status == .stale })
    }

    func testSensitivePersonProfileContextBriefRedactsCloudFields() throws {
        let entityID = UUID()
        let profile = PersonProfile(
            entityID: entityID,
            displayName: "Alex",
            aliases: ["A"],
            roleLabels: ["friend"],
            relationshipToUser: .friend,
            importanceScore: 0.8,
            interactionFrequency: .weekly,
            commonContextLabels: ["planning"],
            userNotes: "Private note",
            aiPortrait: PersonPortrait(summary: "Sensitive portrait summary.", evidenceRecordIDs: [UUID()]),
            sensitivity: .sensitive,
            sourceRecordIDs: [UUID()]
        )

        let redacted = PersonProfileContextBrief(profile: profile, includeSensitive: false)
        XCTAssertEqual(redacted.cloudAction, .redact)
        XCTAssertNil(redacted.portraitSummary)
        XCTAssertNil(redacted.userNotes)
        XCTAssertEqual(redacted.relationshipToUser, .friend)

        var hidden = profile
        hidden.sensitivity = .hiddenFromCloud
        let idOnly = PersonProfileContextBrief(profile: hidden, includeSensitive: false)
        XCTAssertEqual(idOnly.cloudAction, .idOnly)
        XCTAssertTrue(idOnly.aliases.isEmpty)
        XCTAssertNil(idOnly.relationshipToUser)
        XCTAssertNil(idOnly.portraitSummary)
    }

    private func makeRepositoryFixture() -> RepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: IntelligenceTestRecordAnalysisService(),
            cloudIntelligenceService: IntelligenceTestCloudService()
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

private enum IntelligenceTestCloudError: Error {
    case unsupported
}

private struct IntelligenceTestCloudService: CloudIntelligenceServing {
    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        let personName = inferPersonName(from: payload)
        let insight = "Intelligence test summary"
        let analysis = AnalyzeResponseEnvelope(
            tags: ["planning"],
            retrievalTerms: ["planning"],
            emotion: .init(label: "steady", intensity: 0.4, confidence: 0.8, interpretation: nil),
            entities: [
                .init(
                    kind: EntityKind.person.rawValue,
                    name: personName,
                    canonicalName: personName,
                    aliases: [],
                    confidence: 0.85,
                    sourceArtifactIDs: payload.artifacts.map(\.id)
                )
            ],
            candidateEdges: [],
            insight: insight,
            summary: insight,
            salienceScore: 0.7,
            followUp: nil,
            reflectionHint: nil
        )

        return AnalyzeV7ResponseEnvelope(
            analysis: analysis,
            quality: .init(confidence: 0.7, uncertaintyReasons: [], needsUserCheck: [])
        )
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw IntelligenceTestCloudError.unsupported
    }

    private func inferPersonName(from payload: AnalyzeV7RequestPayload) -> String {
        let textSources = [payload.recordShell.rawText] + payload.artifacts.map(\.textContent)
        if textSources.contains(where: { $0.localizedCaseInsensitiveContains("alex") }) {
            return "Alex"
        }
        if let known = payload.knownEntities.first(where: { $0.kind == EntityKind.person.rawValue }) {
            return known.name
        }
        return "Alex"
    }
}

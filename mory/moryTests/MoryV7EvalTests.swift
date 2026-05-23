import SwiftData
import XCTest
@testable import mory

/// Phase 7 golden-fixture eval tests: integration cases that span multiple layers.
/// Unit coverage for individual services (EntityResolutionService, ContextRanker, etc.)
/// already exists in dedicated test files; these tests cover the stitched pipeline.
@MainActor
final class MoryV7EvalTests: XCTestCase {

    // MARK: - Golden fixture: apply addAlias GraphDelta → EntityProfile aliases updated

    func testApplyAddAliasGraphDeltaUpdatesEntityProfile() throws {
        let fixture = makeFixture()
        let entityID = UUID()

        // Seed entity node (kind must be .person to allow profile operations)
        let node = EntityNode(
            id: entityID,
            kind: .person,
            displayName: "Alex",
            canonicalName: "Alex",
            aliases: [],
            provenanceRecordIDs: [],
            createdAt: .now,
            updatedAt: .now,
            confidence: 0.8
        )
        try fixture.repository.upsert(entityNode: node)

        // Seed entity profile so the applier can write back alias
        let profile = EntityProfile(
            entityID: entityID,
            kind: .person,
            displayName: "Alex"
        )
        try fixture.repository.upsertEntityProfile(profile)

        // Store a cloud-proposed addAlias delta
        let delta = GraphDelta(
            source: .cloudAI,
            operations: [
                GraphDeltaOperation(
                    kind: .addAlias,
                    targetType: .entity,
                    targetID: entityID,
                    stringValue: "Alex W."
                )
            ],
            confidence: 0.85,
            requiresUserConfirmation: false
        )
        try fixture.repository.upsertGraphDelta(delta)

        // Delta should initially be unapplied
        XCTAssertNil(try fixture.repository.fetchGraphDeltas(applied: nil, limit: nil).first?.appliedAt)

        // Apply it
        try fixture.repository.applyGraphDelta(delta.id)

        // EntityProfile should now contain the alias
        let updatedProfile = try XCTUnwrap(fixture.repository.fetchEntityProfile(entityID: entityID))
        XCTAssertTrue(
            updatedProfile.aliases.contains("Alex W."),
            "Expected alias 'Alex W.' in profile after applying delta; got \(updatedProfile.aliases)"
        )

        // Delta should be marked applied
        let appliedDeltas = try fixture.repository.fetchGraphDeltas(applied: true, limit: nil)
        XCTAssertFalse(appliedDeltas.isEmpty, "Expected at least one applied delta")
        XCTAssertNotNil(appliedDeltas.first?.appliedAt)
    }

    // MARK: - Golden fixture: applyGraphDelta is idempotent

    func testApplyGraphDeltaIsIdempotent() throws {
        let fixture = makeFixture()
        let entityID = UUID()

        let node = EntityNode(
            id: entityID, kind: .person, displayName: "Bob", canonicalName: "Bob",
            aliases: [], provenanceRecordIDs: [], createdAt: .now, updatedAt: .now, confidence: 0.7
        )
        try fixture.repository.upsert(entityNode: node)

        let profile = EntityProfile(entityID: entityID, kind: .person, displayName: "Bob")
        try fixture.repository.upsertEntityProfile(profile)

        let delta = GraphDelta(
            source: .cloudAI,
            operations: [
                GraphDeltaOperation(
                    kind: .addAlias, targetType: .entity, targetID: entityID,
                    stringValue: "Bobby"
                )
            ],
            confidence: 0.9, requiresUserConfirmation: false
        )
        try fixture.repository.upsertGraphDelta(delta)

        // Apply twice
        try fixture.repository.applyGraphDelta(delta.id)
        try fixture.repository.applyGraphDelta(delta.id) // second call must be no-op

        let updatedProfile = try XCTUnwrap(fixture.repository.fetchEntityProfile(entityID: entityID))
        // Alias appears exactly once (not duplicated by double apply)
        XCTAssertEqual(
            updatedProfile.aliases.filter { $0 == "Bobby" }.count, 1,
            "Alias should appear exactly once even after double apply; got \(updatedProfile.aliases)"
        )
    }

    // MARK: - Golden fixture: sparse first-day memory builds context pack without crash

    func testSparseFirstDayMemoryBuildsContextPackWithoutCrash() async throws {
        let fixture = makeFixture()

        // Create a single memory with no prior history, no entities linked.
        let draft = MemoryCaptureDraft(
            title: "First day",
            rawText: "第一天用 Mory，试试能不能记录一下今天的心情。",
            captureSource: .composer
        )
        let summary = try await fixture.repository.createMemory(from: draft)

        // Context pack must build without throwing even on empty history.
        let builder = ContextPackBuilder(repository: fixture.repository)
        let pack = try await builder.build(targetRecordID: summary.record.id)

        XCTAssertEqual(pack.targetRecordID, summary.record.id)
        // First memory has no related memories in context
        XCTAssertEqual(pack.relatedMemories.count, 0, "Sparse first-day memory should have 0 related memories")
    }

    // MARK: - Golden fixture: person entity merge produces correct primary profile

    func testMergePersonEntitiesProducesCorrectPrimaryProfile() throws {
        let fixture = makeFixture()
        let now = Date.now

        // Seed two person entity nodes
        let aliceID = UUID()
        let aliceNode = EntityNode(
            id: aliceID, kind: .person, displayName: "Alice", canonicalName: "Alice",
            aliases: [], provenanceRecordIDs: [], createdAt: now, updatedAt: now, confidence: 0.9
        )
        let bobID = UUID()
        let bobNode = EntityNode(
            id: bobID, kind: .person, displayName: "Bob", canonicalName: "Bob",
            aliases: [], provenanceRecordIDs: [], createdAt: now, updatedAt: now, confidence: 0.9
        )
        try fixture.repository.upsert(entityNode: aliceNode)
        try fixture.repository.upsert(entityNode: bobNode)

        // Seed profiles so merge can track aliases + source records
        try fixture.repository.upsertEntityProfile(EntityProfile(
            entityID: aliceID, kind: .person, displayName: "Alice"
        ))
        try fixture.repository.upsertEntityProfile(EntityProfile(
            entityID: bobID, kind: .person, displayName: "Bob"
        ))

        // Merge Bob into Alice (simulates wrong-merge scenario)
        let merged = try fixture.repository.mergePersonEntities(
            primaryID: aliceID,
            mergingIDs: [bobID],
            displayName: nil
        )
        XCTAssertEqual(merged.entityID, aliceID, "Merged profile should belong to Alice (primary entity)")

        // Bob's profile should no longer exist (tombstoned / deleted)
        let bobProfileAfterMerge = try fixture.repository.fetchEntityProfile(entityID: bobID)
        XCTAssertNil(bobProfileAfterMerge, "Bob's profile should be removed after merge")

        // Alice's profile should still exist
        let aliceProfileAfterMerge = try fixture.repository.fetchEntityProfile(entityID: aliceID)
        XCTAssertNotNil(aliceProfileAfterMerge, "Alice's profile should persist after merge")

        // A tombstone should record the merge
        let tombstones = try fixture.repository.fetchEntityTombstones(limit: nil)
        let bobTombstone = tombstones.first { $0.oldEntityID == bobID }
        XCTAssertNotNil(bobTombstone, "A tombstone for Bob should exist after merge")
        XCTAssertEqual(bobTombstone?.replacementEntityID, aliceID)
    }

    // MARK: - Golden fixture: affect correction shows up in context pack affect history

    func testAffectCorrectionAppearsInContextPackAffectHistory() async throws {
        let fixture = makeFixture()

        // Create a memory with a default (empty) mood
        let draft = MemoryCaptureDraft(
            title: "Long day",
            rawText: "Today was rough — kept snapping at people, felt like I had no patience.",
            captureSource: .composer
        )
        let summary = try await fixture.repository.createMemory(from: draft)
        let recordID = summary.record.id

        // Apply an affect correction labelling it .irritated (not joking/venting)
        let correction = AffectCorrection(
            recordID: recordID,
            labels: [.irritated],
            toneHints: [.serious]
        )
        _ = try fixture.repository.applyAffectCorrection(correction)

        // Build context pack for the same record (needs a second memory to make it "related")
        let draft2 = MemoryCaptureDraft(
            title: "Next day",
            rawText: "Slept better. Less irritable.",
            captureSource: .composer
        )
        let summary2 = try await fixture.repository.createMemory(from: draft2)

        // Build context pack for memory2 — affectHistory should carry the corrected snapshot
        let builder = ContextPackBuilder(repository: fixture.repository)
        let pack = try await builder.build(targetRecordID: summary2.record.id)

        // The corrected label "irritated" must surface in at least one affectHistory entry
        let allMoods = pack.affectHistory.map { $0.mood }
        let allLabels = pack.affectHistory.flatMap { $0.toneHints.map(\.rawValue) } +
                        pack.affectHistory.map { $0.mood }
        XCTAssertFalse(
            pack.affectHistory.isEmpty,
            "affectHistory should be non-empty after correction; moods: \(allMoods)"
        )
        let hasIrritatedSignal = allLabels.contains { $0.localizedCaseInsensitiveContains("irritat") }
        XCTAssertTrue(
            hasIrritatedSignal,
            "Expected 'irritated' label to appear in context pack affect history; got moods=\(allMoods)"
        )
    }

    // MARK: - Helpers

    private struct EvalFixture {
        let container: ModelContainer
        let repository: MoryMemoryRepository
    }

    private func makeFixture() -> EvalFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: EvalTestAnalysisService()
        )
        return EvalFixture(container: container, repository: repository)
    }
}

// MARK: - Test Doubles

private enum EvalTestError: Error { case unsupported }

private struct EvalTestAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(recordID: record.id, summary: record.rawText, createdAt: .now)
    }

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw EvalTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw EvalTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? { nil }
}

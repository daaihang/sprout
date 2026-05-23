import SwiftData
import XCTest
@testable import mory

@MainActor
final class AffectSnapshotTests: XCTestCase {
    func testAffectMapperDistinguishesJokingFromIrritated() throws {
        let mapper = AffectSnapshotMapper()
        let joking = try XCTUnwrap(mapper.draft(rawMood: "我真服了，开玩笑吐槽一下", source: .userFreeform))
        let irritated = try XCTUnwrap(mapper.draft(rawMood: "真的烦，事情一直卡住", source: .userFreeform))

        XCTAssertGreaterThan(joking.valence ?? -1, irritated.valence ?? 1)
        XCTAssertGreaterThan(joking.dominance ?? 0, irritated.dominance ?? 1)
        XCTAssertTrue(joking.toneHints.contains(.joking))
        XCTAssertTrue(joking.labels.contains(.mockFrustrated))
        XCTAssertTrue(irritated.toneHints.contains(.serious))
        XCTAssertTrue(irritated.labels.contains(.irritated))
        XCTAssertEqual(irritated.appraisal?.goalAlignment, .blocked)
    }

    func testCreateMemoryPersistsStructuredMoodSnapshot() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "After the review",
                rawText: "I felt relieved after the review.",
                mood: "relieved",
                captureSource: .composer,
                artifacts: [.text(title: "After the review", body: "I felt relieved after the review.")]
            )
        )

        let snapshots = try repository.fetchAffectSnapshots(recordID: memory.id, limit: nil)
        let snapshot = try XCTUnwrap(snapshots.first)
        XCTAssertEqual(snapshot.recordID, memory.id)
        XCTAssertTrue(snapshot.labels.contains(.relieved))
        XCTAssertTrue(snapshot.sources.contains(.userSelected))
        XCTAssertGreaterThan(snapshot.valence ?? 0, 0)
    }

    func testAffectCorrectionUpdatesSnapshotAndSelfExpressionPattern() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Voice note",
                rawText: "我真服了。",
                mood: "我真服了",
                captureSource: .audio,
                artifacts: [.text(title: "Voice note", body: "我真服了。")]
            )
        )
        let snapshot = try XCTUnwrap(try repository.fetchAffectSnapshots(recordID: memory.id, limit: nil).first)

        let corrected = try repository.applyAffectCorrection(
            AffectCorrection(
                snapshotID: snapshot.id,
                recordID: memory.id,
                valence: 0.1,
                arousal: 0.6,
                dominance: 0.7,
                labels: [.mockFrustrated],
                toneHints: [.joking, .playful],
                note: "我真服了 here means joking, not real anger."
            )
        )

        XCTAssertTrue(corrected.userConfirmed)
        XCTAssertFalse(corrected.needsUserCheck)
        XCTAssertTrue(corrected.sources.contains(.userCorrected))
        XCTAssertTrue(corrected.toneHints.contains(.joking))

        let corrections = try repository.fetchCorrectionEvents(kind: .affectCorrection, limit: nil)
        XCTAssertEqual(corrections.count, 1)
        XCTAssertEqual(corrections.first?.metadata["snapshotID"], corrected.id.uuidString)

        let selfProfile = try repository.ensureSelfProfile()
        XCTAssertTrue(selfProfile.expressionPatterns.contains {
            $0.phrase.contains("joking")
        })
    }

    func testAffectCorrectionWithoutNoteUpdatesSelfExpressionPatternFromRawInput() async throws {
        let fixture = makeRepositoryFixture()
        let repository = fixture.repository
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Quick tone chip",
                rawText: "我真服了。",
                mood: "我真服了",
                captureSource: .audio,
                artifacts: [.text(title: "Quick tone chip", body: "我真服了。")]
            )
        )
        let snapshot = try XCTUnwrap(try repository.fetchAffectSnapshots(recordID: memory.id, limit: nil).first)

        _ = try repository.applyAffectCorrection(
            AffectCorrection(
                snapshotID: snapshot.id,
                recordID: memory.id,
                labels: [.mockFrustrated],
                toneHints: [.joking, .playful],
                note: nil
            )
        )

        let selfProfile = try repository.ensureSelfProfile()
        XCTAssertTrue(selfProfile.expressionPatterns.contains {
            $0.phrase == "我真服了" && $0.interpretation.contains(ToneHint.joking.rawValue)
        })
    }

    func testJournalingSuggestionStateOfMindMapsAsAffectEvidence() async throws {
        let service = JournalingSuggestionContextService()
        let draft = service.makeCaptureDraft(
            from: JournalingSuggestionDraft(
                title: "Evening walk",
                body: "Walked home after dinner.",
                evidenceItems: [
                    ExternalCaptureEvidenceItem(kind: .reflection, title: "Reflection prompt", value: "What felt meaningful?"),
                    ExternalCaptureEvidenceItem(kind: .location, title: "Riverside"),
                    ExternalCaptureEvidenceItem(kind: .song, title: "Quiet Track", metadata: ["artist": "Mory"])
                ],
                affectEvidence: [
                    ExternalCaptureAffectEvidence(
                        source: .journalSuggestionStateOfMind,
                        label: "calm",
                        labels: ["calm"],
                        valence: 0.6,
                        valenceClassification: "pleasant",
                        kind: "daily mood",
                        rawInput: "calm",
                        confidence: 0.9
                    )
                ]
            )
        )

        XCTAssertEqual(draft.mood, "calm")
        XCTAssertEqual(draft.affectSnapshots.first?.sources, [.journalSuggestionStateOfMind])
        XCTAssertEqual(draft.artifacts.count, 3)

        let fixture = makeRepositoryFixture()
        let memory = try await fixture.repository.createMemory(from: draft)
        let snapshot = try XCTUnwrap(try fixture.repository.fetchAffectSnapshots(recordID: memory.id, limit: nil).first)
        XCTAssertTrue(snapshot.sources.contains(.journalSuggestionStateOfMind))
        XCTAssertTrue(snapshot.userConfirmed)
        XCTAssertEqual(snapshot.valence, 0.6)
    }

    func testJournalingSuggestionAvailabilityFallbackWhenEntitlementUnavailable() {
        let service = JournalingSuggestionContextService(
            capabilityProvider: TestJournalingCapabilityProvider(
                supports: true,
                entitlement: false,
                userEnabled: true
            )
        )

        let availability = service.availability()
        XCTAssertFalse(availability.isAvailable)
        XCTAssertEqual(availability.reason, .missingEntitlement)
    }

    private func makeRepositoryFixture() -> AffectRepositoryFixture {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: AffectTestRecordAnalysisService()
        )
        return AffectRepositoryFixture(container: container, repository: repository)
    }
}

private struct AffectRepositoryFixture {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct TestJournalingCapabilityProvider: JournalingSuggestionCapabilityProviding {
    let supports: Bool
    let entitlement: Bool
    let userEnabled: Bool

    var supportsJournalingSuggestions: Bool { supports }
    var hasJournalingSuggestionEntitlement: Bool { entitlement }
    var userEnabledJournalingSuggestions: Bool { userEnabled }
}

private struct AffectTestRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: [],
            emotionInterpretation: record.userMood ?? "",
            salienceScore: 0.4,
            retrievalTerms: [],
            entityMentions: [],
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
        throw AffectTestError.unsupported
    }

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult {
        throw AffectTestError.unsupported
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        nil
    }
}

private enum AffectTestError: Error {
    case unsupported
}

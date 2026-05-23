import SwiftData
import XCTest
@testable import mory

@MainActor
final class ExternalCaptureInboxTests: XCTestCase {
    func testExternalCaptureInboxRoundTripAndImportMarksImported() async throws {
        let harness = makeHarness()
        let repository = harness.repository
        let request = ExternalCaptureRequest(
            sourceKind: .appIntent,
            title: "Shortcut note",
            text: "Remember the dinner idea from the train.",
            url: "https://example.com/dinner",
            context: "appIntent:test",
            affectDrafts: [
                AffectSnapshotDraft(
                    labels: [.curious],
                    toneHints: [.serious],
                    sources: [.userSelected],
                    confidence: 1,
                    evidenceSummary: "shortcut chip",
                    userConfirmed: true,
                    rawInput: "interested"
                )
            ]
        )

        let queued = try repository.enqueueExternalCapture(request, receivedAt: Date(timeIntervalSince1970: 1_800_000_000))
        let pending = try repository.fetchExternalCaptureInbox(status: .pending, limit: nil)
        XCTAssertEqual(pending.map(\.id), [queued.id])

        let draft = try ExternalCaptureInboxCodec().makeDraft(from: queued)
        XCTAssertEqual(draft.title, "Shortcut note")
        XCTAssertEqual(draft.rawText, "Remember the dinner idea from the train.")
        XCTAssertEqual(draft.affectSnapshots.first?.labels, [.curious])
        XCTAssertEqual(draft.artifacts.count, 2)

        let memory = try await repository.createMemoryFromExternalCaptureInboxItem(queued.id)
        XCTAssertEqual(memory.record.rawText, "Remember the dinner idea from the train.")
        XCTAssertEqual(try repository.fetchExternalCaptureInbox(status: .pending, limit: nil), [])

        let imported = try XCTUnwrap(try repository.fetchExternalCaptureInbox(status: .imported, limit: nil).first)
        XCTAssertEqual(imported.id, queued.id)
        XCTAssertEqual(imported.importedRecordID, memory.record.id)
        XCTAssertEqual(try repository.fetchAffectSnapshots(recordID: memory.record.id, limit: nil).first?.labels, [.curious])
    }

    func testJournalingSuggestionInboxPreservesContextArtifactsAndAffect() throws {
        let harness = makeHarness()
        let repository = harness.repository
        let suggestion = JournalingSuggestionDraft(
            title: "Evening walk",
            body: "Walked after dinner and felt settled.",
            reflectionPrompt: "What made this feel calm?",
            locationTitle: "Riverside",
            latitude: 31.23,
            longitude: 121.47,
            songTitle: "Night Drive",
            artistName: "Mory Test",
            stateOfMindLabel: "calm",
            stateOfMindValence: 0.7,
            stateOfMindArousal: 0.2,
            stateOfMindDominance: 0.8,
            createdAt: Date(timeIntervalSince1970: 1_800_000_001)
        )

        let item = try repository.enqueueJournalingSuggestion(suggestion, receivedAt: suggestion.createdAt)
        let draft = try ExternalCaptureInboxCodec().makeDraft(from: item)

        XCTAssertEqual(item.sourceKind, .journalingSuggestion)
        XCTAssertEqual(draft.title, "Evening walk")
        XCTAssertTrue(draft.inputContext?.contains("journalingSuggestion") == true)
        XCTAssertEqual(draft.affectSnapshots.first?.sources, [.journalSuggestionStateOfMind])
        XCTAssertEqual(draft.affectSnapshots.first?.valence, 0.7)
        XCTAssertEqual(draft.artifacts.count, 3)
    }

    func testDismissExternalCaptureInboxItemRemovesItFromPending() throws {
        let harness = makeHarness()
        let repository = harness.repository
        let item = try repository.enqueueExternalCapture(
            ExternalCaptureRequest(sourceKind: .shareSheet, title: "Shared link", text: "Shared text"),
            receivedAt: .now
        )

        try repository.dismissExternalCaptureInboxItem(item.id)

        XCTAssertTrue(try repository.fetchExternalCaptureInbox(status: .pending, limit: nil).isEmpty)
        let dismissed = try XCTUnwrap(try repository.fetchExternalCaptureInbox(status: .dismissed, limit: nil).first)
        XCTAssertEqual(dismissed.id, item.id)
        XCTAssertNotNil(dismissed.dismissedAt)
    }

    func testExternalCaptureInboxWriterUsesActiveOwnerScope() throws {
        let suiteName = "ExternalCaptureInboxTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mory-external-inbox-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: baseDirectory) }

        let ownerID = "external-owner"
        defaults.set(ownerID, forKey: LocalDataOwnerRegistry.activeOwnerDefaultsKey)
        let registry = LocalDataOwnerRegistry(defaults: defaults, baseDirectory: baseDirectory)
        let writer = ExternalCaptureInboxWriter(registry: registry, defaults: defaults)

        let item = try writer.enqueue(
            ExternalCaptureRequest(sourceKind: .appIntent, title: "Intent", text: "Queued outside the app.")
        )

        let stored = try ExternalCaptureInboxDefaultsStore(
            defaults: defaults,
            scope: registry.scope(for: ownerID)
        ).fetch(status: nil, limit: nil)

        XCTAssertEqual(stored.map(\.id), [item.id])
        XCTAssertEqual(stored.first?.sourceKind, .appIntent)
    }

    private func makeHarness() -> ExternalCaptureRepositoryHarness {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let suiteName = "ExternalCaptureInboxTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: ExternalCaptureNoopAnalysisService(),
            externalCaptureInboxStore: ExternalCaptureInboxDefaultsStore(
                defaults: defaults,
                scope: .owner("external-capture-tests")
            )
        )
        return ExternalCaptureRepositoryHarness(container: container, repository: repository)
    }
}

private struct ExternalCaptureRepositoryHarness {
    let container: ModelContainer
    let repository: MoryMemoryRepository
}

private struct ExternalCaptureNoopAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: record.rawText,
            themes: [],
            emotionInterpretation: "not analyzed",
            salienceScore: 0,
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
        ReflectionServiceResult(
            title: "Reflection",
            body: "No-op reflection",
            evidenceSummary: "",
            confidence: 0,
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

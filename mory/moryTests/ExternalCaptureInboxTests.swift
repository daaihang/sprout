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
            evidenceItems: [
                ExternalCaptureEvidenceItem(kind: .link, title: "Shortcut note", value: "https://example.com/dinner", metadata: ["url": "https://example.com/dinner"])
            ],
            affectEvidence: [
                ExternalCaptureAffectEvidence(
                    source: .userSelected,
                    label: "curious",
                    labels: ["curious"],
                    toneHints: ["serious"],
                    rawInput: "interested",
                    confidence: 1,
                    userConfirmed: true
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
            evidenceItems: [
                ExternalCaptureEvidenceItem(kind: .reflection, title: "Reflection prompt", value: "What made this feel calm?"),
                ExternalCaptureEvidenceItem(kind: .location, title: "Riverside", metadata: ["latitude": "31.23", "longitude": "121.47"]),
                ExternalCaptureEvidenceItem(kind: .song, title: "Night Drive", metadata: ["artist": "Mory Test"])
            ],
            affectEvidence: [
                ExternalCaptureAffectEvidence(
                    source: .journalSuggestionStateOfMind,
                    label: "calm",
                    labels: ["calm"],
                    valence: 0.7,
                    valenceClassification: "pleasant",
                    kind: "daily mood",
                    rawInput: "calm",
                    confidence: 0.9
                )
            ],
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

    func testShareSheetImageAttachmentBecomesPhotoDraft() throws {
        let request = ExternalCaptureRequest(
            sourceKind: .shareSheet,
            title: "Shared screenshot",
            text: "Screenshot from share sheet.",
            context: "shareExtension:test",
            attachments: [
                ExternalCaptureAttachmentDraft(
                    kind: .image,
                    filename: "screenshot.jpg",
                    contentType: "public.jpeg",
                    storedFileName: nil,
                    summary: "Shared screenshot"
                )
            ]
        )

        let item = try ExternalCaptureInboxCodec().makeItem(from: request)
        let draft = try ExternalCaptureInboxCodec().makeDraft(from: item)

        XCTAssertEqual(draft.title, "Shared screenshot")
        XCTAssertTrue(draft.artifacts.contains { artifact in
            if case .photo = artifact { return true }
            return false
        })
    }

    func testShareDeepLinkParsesExternalCaptureComposeAction() throws {
        let id = UUID()
        let link = try XCTUnwrap(URL(string: "mory://external-capture?id=\(id.uuidString)&action=compose"))
        let parsed = try XCTUnwrap(ExternalCaptureDeepLink(url: link))
        XCTAssertEqual(parsed.itemID, id)
        XCTAssertEqual(parsed.action, .compose)
    }

    func testExternalCaptureWireContractsRejectNonV2Payloads() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let v1Request = Data("""
        {"version":1,"sourceKind":"shareSheet","text":"old payload"}
        """.utf8)
        XCTAssertThrowsError(try decoder.decode(ExternalCaptureRequest.self, from: v1Request))

        let missingVersionRequest = Data("""
        {"sourceKind":"shareSheet","text":"old payload"}
        """.utf8)
        XCTAssertThrowsError(try decoder.decode(ExternalCaptureRequest.self, from: missingVersionRequest))

        let v1Suggestion = Data("""
        {"version":1,"title":"old journaling","createdAt":"2026-05-24T00:00:00Z"}
        """.utf8)
        XCTAssertThrowsError(try decoder.decode(JournalingSuggestionDraft.self, from: v1Suggestion))

        let v1InboxItem = Data("""
        {"version":1,"id":"00000000-0000-0000-0000-000000000001","payloadKind":"externalCapture","sourceKind":"shareSheet","summary":"old","payloadData":"","status":"pending","receivedAt":"2026-05-24T00:00:00Z","updatedAt":"2026-05-24T00:00:00Z"}
        """.utf8)
        XCTAssertThrowsError(try decoder.decode(ExternalCaptureInboxItem.self, from: v1InboxItem))
    }

    func testJournalingSuggestionMapsMediaAndOfficialStateOfMindEvidence() throws {
        let service = JournalingSuggestionContextService()
        let draft = service.makeCaptureDraft(
            from: JournalingSuggestionDraft(
                title: "System suggestion",
                body: "Selected from Apple Journaling Suggestions.",
                evidenceItems: [
                    ExternalCaptureEvidenceItem(kind: .location, title: "Riverside"),
                    ExternalCaptureEvidenceItem(kind: .stateOfMind, title: "calm", metadata: [
                        "labels": "calm,peaceful",
                        "associations": "friends,health",
                        "valence": "0.64",
                        "classification": "pleasant",
                        "kind": "daily mood"
                    ])
                ],
                affectEvidence: [
                    ExternalCaptureAffectEvidence(
                        source: .journalSuggestionStateOfMind,
                        label: "calm",
                        labels: ["calm", "peaceful"],
                        associations: ["friends", "health"],
                        valence: 0.64,
                        valenceClassification: "pleasant",
                        kind: "daily mood",
                        rawInput: "calm",
                        confidence: 0.9
                    )
                ],
                attachments: [
                    ExternalCaptureAttachmentDraft(
                        kind: .image,
                        filename: "journal-photo.jpg",
                        contentType: "image/jpeg",
                        summary: "Journaling photo"
                    ),
                    ExternalCaptureAttachmentDraft(
                        kind: .video,
                        filename: "journal-video.mov",
                        contentType: "video/quicktime",
                        summary: "Journaling video"
                    )
                ]
            )
        )

        XCTAssertTrue(draft.artifacts.contains { artifact in
            if case .photo = artifact { return true }
            return false
        })
        XCTAssertTrue(draft.artifacts.contains { artifact in
            if case .video = artifact { return true }
            return false
        })
        let affect = try XCTUnwrap(draft.affectSnapshots.first)
        XCTAssertEqual(affect.sources, [.journalSuggestionStateOfMind])
        XCTAssertEqual(affect.valence, 0.64)
        XCTAssertNil(affect.arousal)
        XCTAssertNil(affect.dominance)
        XCTAssertTrue(affect.evidenceSummary?.contains("labels=calm,peaceful") == true)
        XCTAssertTrue(affect.evidenceSummary?.contains("associations=friends,health") == true)
        XCTAssertTrue(affect.evidenceSummary?.contains("classification=pleasant") == true)
        XCTAssertTrue(affect.evidenceSummary?.contains("kind=daily mood") == true)
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

    func testOwnerScopedInboxReadsSharedInboxFromShareExtension() throws {
        let ownerSuiteName = "ExternalCaptureInboxTests.owner.\(UUID().uuidString)"
        let sharedSuiteName = "ExternalCaptureInboxTests.shared.\(UUID().uuidString)"
        let ownerDefaults = try XCTUnwrap(UserDefaults(suiteName: ownerSuiteName))
        let sharedDefaults = try XCTUnwrap(UserDefaults(suiteName: sharedSuiteName))
        defer {
            ownerDefaults.removePersistentDomain(forName: ownerSuiteName)
            sharedDefaults.removePersistentDomain(forName: sharedSuiteName)
        }

        let item = try ExternalCaptureInboxCodec().makeItem(
            from: ExternalCaptureRequest(
                sourceKind: .shareSheet,
                title: "Shared URL",
                text: "https://example.com/shared",
                url: "https://example.com/shared",
                context: "shareExtension:test"
            )
        )
        try ExternalCaptureInboxDefaultsStore(
            defaults: sharedDefaults,
            scope: .legacy
        ).upsert(item)

        let visibleItems = try ExternalCaptureInboxDefaultsStore(
            defaults: ownerDefaults,
            scope: .owner("active-owner"),
            includeSharedInboxFallback: true,
            sharedInboxDefaults: sharedDefaults
        ).fetch(status: .pending, limit: nil)

        XCTAssertEqual(visibleItems.map(\.id), [item.id])
        XCTAssertEqual(try ExternalCaptureInboxCodec().makeDraft(from: visibleItems[0]).rawText, "https://example.com/shared")
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

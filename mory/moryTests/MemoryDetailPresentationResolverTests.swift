import XCTest
@testable import mory

final class MemoryDetailPresentationResolverTests: XCTestCase {
    private let resolver = MemoryDetailPresentationResolver()

    func testPureTextResolvesToText() {
        let snapshot = makeSnapshot(rawText: "A plain written memory with enough substance to read as text.")
        XCTAssertEqual(resolve(snapshot).mode, .text)
    }

    func testPhotoDominantResolvesToGallery() {
        let snapshot = makeSnapshot(
            rawText: "Short photo note.",
            artifacts: [
                makeArtifact(kind: .photo, summary: "First photo"),
                makeArtifact(kind: .photo, summary: "Second photo")
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .gallery)
    }

    func testAudioDominantResolvesToAudio() {
        let snapshot = makeSnapshot(
            rawText: "Recorded transcript from a short voice note.",
            artifacts: [
                makeArtifact(kind: .audio, summary: "Audio capture", metadata: ["transcriptionText": "Recorded transcript"])
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .audio)
    }

    func testOnlyContextResolvesToCheckIn() {
        let snapshot = makeSnapshot(
            rawText: "Context check-in",
            artifacts: [
                makeArtifact(kind: .location, summary: "Cafe", metadata: ["captureOrigin": CaptureArtifactOrigin.context.rawValue]),
                makeArtifact(kind: .weather, summary: "Sunny")
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .checkIn)
    }

    func testLinkDominantResolvesToLink() {
        let snapshot = makeSnapshot(
            rawText: "Read later.",
            artifacts: [
                makeArtifact(kind: .link, summary: "Article", metadata: ["url": "https://example.com"])
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .link)
    }

    func testLongMixedMediaResolvesToArticle() {
        let longText = String(repeating: "This is a long multimedia memory with enough body text. ", count: 18)
        let snapshot = makeSnapshot(
            rawText: longText,
            artifacts: [
                makeArtifact(kind: .photo, summary: "Photo"),
                makeArtifact(kind: .audio, summary: "Audio"),
                makeArtifact(kind: .link, summary: "Link")
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .article)
    }

    func testComplexShortMixedMediaResolvesToStory() {
        let snapshot = makeSnapshot(
            rawText: "Dinner, one photo, a song, and a follow-up task.",
            artifacts: [
                makeArtifact(kind: .photo, summary: "Photo"),
                makeArtifact(kind: .music, summary: "Song"),
                makeArtifact(kind: .todo, summary: "Follow up")
            ]
        )
        XCTAssertEqual(resolve(snapshot).mode, .story)
    }

    func testRecordPreferenceOverridesAutomaticAndGlobalRules() {
        var settings = UserSettingsPreference.defaults
        settings.detailPresentationStrategy = .fixed
        settings.fixedDetailPresentationMode = .gallery
        let snapshot = makeSnapshot(rawText: "A plain written memory with enough substance to read as text.")
        let override = MemoryDetailPresentationPreference(recordID: snapshot.record.id, mode: .audio)

        let result = resolver.resolve(snapshot: snapshot, userPreference: settings, recordPreference: override)

        XCTAssertEqual(result.mode, .audio)
    }

    func testGlobalFixedPreferenceOverridesAutomaticWhenNoRecordPreference() {
        var settings = UserSettingsPreference.defaults
        settings.detailPresentationStrategy = .fixed
        settings.fixedDetailPresentationMode = .gallery
        let snapshot = makeSnapshot(rawText: "A plain written memory with enough substance to read as text.")

        let result = resolver.resolve(snapshot: snapshot, userPreference: settings, recordPreference: nil)

        XCTAssertEqual(result.mode, .gallery)
    }

    private func resolve(_ snapshot: MemoryDetailSnapshot) -> MemoryDetailPresentationSnapshot {
        resolver.resolve(snapshot: snapshot, userPreference: .defaults, recordPreference: nil)
    }

    private func makeSnapshot(rawText: String, artifacts: [Artifact] = []) -> MemoryDetailSnapshot {
        MemoryDetailSnapshot(
            record: RecordShell(
                createdAt: Date(timeIntervalSince1970: 1_800_000_000),
                updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
                captureSource: .composer,
                rawText: rawText,
                artifactIDs: artifacts.map(\.id)
            ),
            artifacts: artifacts,
            analysis: nil,
            pipelineStatus: nil,
            entities: [],
            edges: [],
            arcs: [],
            reflections: []
        )
    }

    private func makeArtifact(
        kind: ArtifactKind,
        summary: String,
        metadata: [String: String] = [:]
    ) -> Artifact {
        Artifact(
            recordID: UUID(),
            kind: kind,
            title: summary,
            summary: summary,
            textContent: summary,
            metadata: metadata,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

private struct StubRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Stub summary",
            themes: [],
            emotionInterpretation: "",
            salienceScore: 0.5,
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
            title: "Stub reflection",
            body: "Stub reflection body",
            evidenceSummary: "Stub evidence",
            confidence: 0.5,
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

@MainActor
final class MemoryDetailPresentationPreferenceRepositoryTests: XCTestCase {
    func testSavesFetchesAndClearsRecordPresentationPreference() throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )
        let recordID = UUID()

        XCTAssertNil(try repository.fetchMemoryDetailPresentationPreference(recordID: recordID))

        try repository.saveMemoryDetailPresentationPreference(
            MemoryDetailPresentationPreference(recordID: recordID, mode: .gallery)
        )
        XCTAssertEqual(try repository.fetchMemoryDetailPresentationPreference(recordID: recordID)?.mode, .gallery)

        try repository.saveMemoryDetailPresentationPreference(
            MemoryDetailPresentationPreference(recordID: recordID, mode: .audio)
        )
        XCTAssertEqual(try repository.fetchMemoryDetailPresentationPreference(recordID: recordID)?.mode, .audio)

        try repository.clearMemoryDetailPresentationPreference(recordID: recordID)
        XCTAssertNil(try repository.fetchMemoryDetailPresentationPreference(recordID: recordID))
    }

    func testDeleteMemoryClearsRecordPresentationPreference() async throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )
        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                rawText: "A memory whose presentation preference should be removed.",
                artifacts: [.text(title: nil, body: "A memory whose presentation preference should be removed.")]
            )
        )
        try repository.saveMemoryDetailPresentationPreference(
            MemoryDetailPresentationPreference(recordID: memory.record.id, mode: .gallery)
        )

        try repository.deleteMemory(recordID: memory.record.id)

        XCTAssertNil(try repository.fetchMemoryDetailPresentationPreference(recordID: memory.record.id))
    }

    func testGlobalPresentationPreferencePersistsInUserSettings() throws {
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: StubRecordAnalysisService()
        )

        var preference = try repository.fetchUserSettingsPreference()
        preference.detailPresentationStrategy = .fixed
        preference.fixedDetailPresentationMode = .article
        try repository.saveUserSettingsPreference(preference)

        let stored = try repository.fetchUserSettingsPreference()
        XCTAssertEqual(stored.detailPresentationStrategy, .fixed)
        XCTAssertEqual(stored.fixedDetailPresentationMode, .article)
    }
}

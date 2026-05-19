import CoreSpotlight
import SwiftData
import XCTest
@testable import mory

@MainActor
final class SpotlightSearchFoundationTests: XCTestCase {
    func testSpotlightMemoryItemBuilderMapsMemoryTextContextAndAnalysis() {
        let recordID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let textArtifact = Artifact(
            recordID: recordID,
            kind: .text,
            title: "Morning plan",
            summary: "Protected mornings before launch.",
            textContent: "Protected mornings before launch.",
            payload: .text("Protected mornings before launch."),
            createdAt: date,
            updatedAt: date
        )
        let audioArtifact = Artifact(
            recordID: recordID,
            kind: .audio,
            title: "Voice note",
            summary: "Audio capture",
            textContent: "I need quiet mornings.",
            createdAt: date,
            updatedAt: date
        )
        let locationArtifact = Artifact(
            recordID: recordID,
            kind: .location,
            title: "Cafe",
            summary: "Cafe near the studio",
            textContent: "Cafe near the studio",
            metadata: ["latitude": "31.2", "longitude": "121.4"],
            createdAt: date,
            updatedAt: date
        )
        let memory = MemorySummary(
            record: RecordShell(
                id: recordID,
                createdAt: date,
                updatedAt: date,
                captureSource: .composer,
                rawText: "Launch planning with Linh.",
                userMood: "focused",
                inputContext: "typed in debug",
                artifactIDs: [textArtifact.id, audioArtifact.id, locationArtifact.id]
            ),
            primaryArtifact: textArtifact,
            contextArtifacts: [locationArtifact],
            artifactCount: 3,
            pipelineStatus: nil
        )
        let analysis = RecordAnalysisSnapshot(
            recordID: recordID,
            summary: "Planning before launch",
            themes: ["launch", "focus"],
            emotionInterpretation: "protective",
            salienceScore: 0.82,
            retrievalTerms: ["quiet mornings", "planning"],
            entityMentions: [EntityReference(kind: .person, name: "Linh", aliases: ["L"], confidence: 0.9)],
            createdAt: date
        )

        let item = SpotlightSearchableItemBuilder().makeMemoryItem(
            memory: memory,
            artifacts: [textArtifact, audioArtifact, locationArtifact],
            analysis: analysis
        )

        XCTAssertEqual(item.uniqueIdentifier, SpotlightSearchableItemIdentifier.memory(recordID))
        XCTAssertEqual(item.domainIdentifier, SpotlightSearchableItemIdentifier.memoryDomain)
        XCTAssertEqual(item.attributeSet.title, "Morning plan")
        XCTAssertEqual(item.attributeSet.contentDescription, "Protected mornings before launch.")
        XCTAssertTrue(item.attributeSet.textContent?.contains("quiet mornings") == true)
        XCTAssertTrue(item.attributeSet.keywords?.contains("launch") == true)
        XCTAssertEqual(item.attributeSet.namedLocation, "Cafe")
        XCTAssertEqual(item.attributeSet.latitude?.doubleValue, 31.2)
        XCTAssertEqual(item.attributeSet.longitude?.doubleValue, 121.4)
        XCTAssertEqual(item.attributeSet.rankingHint?.intValue, 82)
    }

    func testSpotlightMemoryItemBuilderScopesDomainAndIdentifierByOwner() {
        let recordID = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let artifact = Artifact(
            recordID: recordID,
            kind: .text,
            title: "Owner scoped memory",
            summary: "Owner scoped memory",
            textContent: "Owner scoped memory",
            createdAt: date,
            updatedAt: date
        )
        let memory = MemorySummary(
            record: RecordShell(
                id: recordID,
                createdAt: date,
                updatedAt: date,
                captureSource: .composer,
                rawText: "Owner scoped memory",
                artifactIDs: [artifact.id]
            ),
            primaryArtifact: artifact,
            contextArtifacts: [],
            artifactCount: 1,
            pipelineStatus: nil
        )
        let ownerID = "user:apple-a"

        let item = SpotlightSearchableItemBuilder(ownerID: ownerID).makeMemoryItem(
            memory: memory,
            artifacts: [artifact],
            analysis: nil
        )

        XCTAssertEqual(item.uniqueIdentifier, SpotlightSearchableItemIdentifier.memory(recordID, ownerID: ownerID))
        XCTAssertEqual(item.domainIdentifier, SpotlightSearchableItemIdentifier.memoryDomain(ownerID: ownerID))
        XCTAssertEqual(SpotlightSearchableItemIdentifier.parseMemoryID(from: item.uniqueIdentifier), recordID)
    }

    func testSearchResultMergerPlacesSemanticMatchesBeforeFallbackAndDeduplicates() {
        let first = makeMemory(title: "Semantic match")
        let second = makeMemory(title: "Fallback match")
        let fallback = SearchSnapshot(
            query: "mornings",
            memories: [SearchMemoryResultSnapshot(memory: second)],
            entities: [],
            arcs: [],
            reflections: [],
            retrievalSources: [.exactFallback, .graph]
        )

        let merged = SearchResultMerger().merge(
            fallback: fallback,
            semanticMemoryIDs: [first.id, second.id],
            memories: [first, second],
            limit: 10
        )

        XCTAssertEqual(merged.memories.map(\.id), [first.id, second.id])
        XCTAssertEqual(merged.semanticMemoryIDs, [first.id, second.id])
        XCTAssertEqual(merged.semanticSearchStatus, .succeeded(resultCount: 2))
        XCTAssertEqual(merged.retrievalSources, [.exactFallback, .graph, .spotlight])
        XCTAssertTrue(merged.memories[0].explanations.contains { $0.source == .spotlight })
        XCTAssertTrue(merged.memories[1].explanations.contains { $0.source == .spotlight })
    }

    func testRepositorySemanticSearchUsesSpotlightIDsAndExactFallback() async throws {
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight
        )
        try enableSemanticSearch(repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Cafe launch",
                rawText: "Talked with Linh at the cafe about launch.",
                mood: "focused",
                inputContext: "typed in debug",
                captureSource: .composer,
                artifacts: [.text(title: "Cafe launch", body: "Talked with Linh at the cafe about launch.")]
            )
        )
        spotlight.searchMemoryIDsResult = [memory.id]

        let result = try await repository.searchSemanticFirst(query: "protecting mornings", limit: 10)

        XCTAssertEqual(result.memories.first?.id, memory.id)
        XCTAssertEqual(result.semanticSearchStatus, .succeeded(resultCount: 1))
        XCTAssertTrue(result.retrievalSources.contains(.spotlight))
        XCTAssertEqual(spotlight.searchedDomains, [SpotlightSearchableItemIdentifier.memoryDomain])
    }

    func testRepositoryRebuildSpotlightIndexIndexesCurrentMemoriesWhenEnabled() async throws {
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight
        )
        try enableSemanticSearch(repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Indexed memory",
                rawText: "This memory should be indexed.",
                captureSource: .composer,
                artifacts: [.text(title: "Indexed memory", body: "This memory should be indexed.")]
            )
        )
        spotlight.indexedItems = []

        let report = try await repository.rebuildSpotlightIndex()

        XCTAssertEqual(report.indexedItemCount, 1)
        XCTAssertEqual(spotlight.indexedItems.map(\.uniqueIdentifier), [
            SpotlightSearchableItemIdentifier.memory(memory.id)
        ])
    }

    func testRepositoryCreateUpdateDeleteDriveSpotlightIndexMutations() async throws {
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight
        )
        try enableSemanticSearch(repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Lifecycle memory",
                rawText: "Created for indexing lifecycle checks.",
                captureSource: .composer,
                artifacts: [.text(title: "Lifecycle memory", body: "Created for indexing lifecycle checks.")]
            )
        )
        XCTAssertEqual(
            spotlight.indexedItems.map(\.uniqueIdentifier),
            [SpotlightSearchableItemIdentifier.memory(memory.id)]
        )

        _ = try await repository.updateMemory(
            recordID: memory.id,
            draft: MemoryEditDraft(
                rawText: "Updated indexing content.",
                userMood: "clear",
                inputContext: "manual edit"
            )
        )
        XCTAssertEqual(spotlight.indexedItems.count, 2)
        XCTAssertEqual(spotlight.indexedItems.last?.uniqueIdentifier, SpotlightSearchableItemIdentifier.memory(memory.id))

        try repository.deleteMemory(recordID: memory.id)
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(
            spotlight.deletedIdentifiers,
            [SpotlightSearchableItemIdentifier.memory(memory.id)]
        )
    }

    func testRepositorySemanticSearchDisabledSkipsSpotlightAndIndexing() async throws {
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight
        )
        try disableSemanticSearch(repository)

        _ = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Disabled semantic",
                rawText: "Should stay on fallback search only.",
                captureSource: .composer,
                artifacts: [.text(title: "Disabled semantic", body: "Should stay on fallback search only.")]
            )
        )
        XCTAssertTrue(spotlight.indexedItems.isEmpty)

        spotlight.searchMemoryIDsResult = [UUID()]
        let result = try await repository.searchSemanticFirst(query: "fallback", limit: 10)
        XCTAssertEqual(result.semanticSearchStatus, .disabled)
        XCTAssertEqual(spotlight.searchQueries.count, 0)
        XCTAssertFalse(result.retrievalSources.contains(.spotlight))
    }

    func testDeleteSpotlightIndexCallsDomainDelete() async throws {
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight
        )

        let report = try await repository.deleteSpotlightIndex()
        XCTAssertEqual(report.deletedItemCount, 0)
        XCTAssertEqual(spotlight.deletedDomains, [SpotlightSearchableItemIdentifier.memoryDomain])
    }

    func testRepositorySpotlightMutationsUseOwnerScopedDomainWhenOwnerIsProvided() async throws {
        let ownerID = "user:apple-a"
        let ownerDomain = SpotlightSearchableItemIdentifier.memoryDomain(ownerID: ownerID)
        let spotlight = RecordingSpotlightIndexService()
        let container = MoryPersistenceStack.makeSharedModelContainer(inMemory: true)
        let repository = MoryMemoryRepository(
            modelContext: container.mainContext,
            analysisService: SearchStubRecordAnalysisService(),
            spotlightIndexService: spotlight,
            localDataOwnerID: ownerID
        )
        try enableSemanticSearch(repository)

        let memory = try await repository.createMemory(
            from: MemoryCaptureDraft(
                title: "Owner indexed memory",
                rawText: "This memory should be indexed inside the owner domain.",
                captureSource: .composer,
                artifacts: [.text(title: "Owner indexed memory", body: "This memory should be indexed inside the owner domain.")]
            )
        )
        XCTAssertEqual(spotlight.indexedItems.last?.domainIdentifier, ownerDomain)
        XCTAssertEqual(spotlight.indexedItems.last?.uniqueIdentifier, SpotlightSearchableItemIdentifier.memory(memory.id, ownerID: ownerID))

        spotlight.searchMemoryIDsResult = [memory.id]
        _ = try await repository.searchSemanticFirst(query: "owner indexed", limit: 10)
        XCTAssertEqual(spotlight.searchedDomains.last, ownerDomain)

        let report = try await repository.deleteSpotlightIndex()
        XCTAssertEqual(report.deletedItemCount, 0)
        XCTAssertEqual(spotlight.deletedDomains.last, ownerDomain)
    }

    private func enableSemanticSearch(_ repository: MoryMemoryRepository) throws {
        var flags = try repository.fetchV6FeatureFlags()
        flags.semanticSearch = true
        try repository.saveV6FeatureFlags(flags)

        var preferences = try repository.fetchIntelligencePreferences()
        preferences.semanticSearchEnabled = true
        try repository.saveIntelligencePreferences(preferences)
    }

    private func disableSemanticSearch(_ repository: MoryMemoryRepository) throws {
        var flags = try repository.fetchV6FeatureFlags()
        flags.semanticSearch = false
        try repository.saveV6FeatureFlags(flags)

        var preferences = try repository.fetchIntelligencePreferences()
        preferences.semanticSearchEnabled = false
        try repository.saveIntelligencePreferences(preferences)
    }

    private func makeMemory(title: String) -> MemorySummary {
        let id = UUID()
        let now = Date()
        let artifact = Artifact(
            recordID: id,
            kind: .text,
            title: title,
            summary: title,
            textContent: title,
            createdAt: now,
            updatedAt: now
        )
        return MemorySummary(
            record: RecordShell(
                id: id,
                createdAt: now,
                updatedAt: now,
                captureSource: .composer,
                rawText: title,
                artifactIDs: [artifact.id]
            ),
            primaryArtifact: artifact,
            contextArtifacts: [],
            artifactCount: 1,
            pipelineStatus: nil
        )
    }
}

@MainActor
private final class RecordingSpotlightIndexService: SpotlightIndexServicing {
    var isIndexingAvailable = true
    var indexedItems: [CSSearchableItem] = []
    var deletedIdentifiers: [String] = []
    var deletedDomains: [String] = []
    var searchMemoryIDsResult: [UUID] = []
    var searchQueries: [String] = []
    var searchedDomains: [String] = []

    func indexItems(_ items: [CSSearchableItem]) async throws {
        indexedItems.append(contentsOf: items)
    }

    func deleteItems(identifiers: [String]) async throws {
        deletedIdentifiers.append(contentsOf: identifiers)
    }

    func deleteDomain(_ domainIdentifier: String) async throws {
        deletedDomains.append(domainIdentifier)
    }

    func searchMemoryIDs(query: String, limit: Int, domainIdentifier: String) async throws -> [UUID] {
        searchQueries.append(query)
        searchedDomains.append(domainIdentifier)
        return Array(searchMemoryIDsResult.prefix(limit))
    }
}

private struct SearchStubRecordAnalysisService: RecordAnalysisServing {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Search stub summary",
            themes: ["search"],
            emotionInterpretation: "focused",
            salienceScore: 0.75,
            retrievalTerms: ["semantic", "spotlight"],
            entityMentions: [],
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
            title: "Search reflection",
            body: "Search reflection body.",
            evidenceSummary: artifacts.map(\.summary).joined(separator: " | "),
            confidence: 0.7,
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

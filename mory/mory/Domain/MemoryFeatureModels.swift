import Foundation

struct MemoryCaptureDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var mood: String?
    var inputContext: String?
    var captureSource: CaptureSource

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        captureSource: CaptureSource = .composer
    ) {
        self.title = title
        self.rawText = rawText
        self.mood = mood
        self.inputContext = inputContext
        self.captureSource = captureSource
    }
}

struct MemorySummary: Identifiable, Hashable, Sendable {
    let record: RecordShell
    let primaryArtifact: Artifact?
    let artifactCount: Int

    var id: UUID { record.id }

    var title: String {
        if let artifactTitle = primaryArtifact?.title.trimmedOrNil {
            return artifactTitle
        }
        return record.rawText.firstMeaningfulLine ?? "Untitled Memory"
    }

    var summaryText: String {
        if let artifactSummary = primaryArtifact?.summary.trimmedOrNil {
            return artifactSummary
        }
        return record.rawText.trimmedOrNil ?? "No summary yet"
    }
}

struct MemoryDetailSnapshot: Hashable, Sendable {
    let record: RecordShell
    let artifacts: [Artifact]
    let analysis: RecordAnalysisSnapshot?
}

struct HomeBoardItemSnapshot: Identifiable, Hashable, Sendable {
    let compositionItem: CompositionItem
    let memory: MemorySummary?

    var id: UUID { compositionItem.id }
}

struct HomeBoardSnapshot: Hashable, Sendable {
    let board: Board
    let composition: Composition
    let items: [HomeBoardItemSnapshot]
}

struct SearchSnapshot: Hashable, Sendable {
    var query: String
    var memories: [MemorySummary]
    var entities: [EntityNode]
    var arcs: [TemporalArc]
    var reflections: [ReflectionSnapshot]
}

struct PersonMemorySummary: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let themeLabels: [String]
    let reflectionCount: Int

    var id: UUID { entity.id }
}

struct DebugMemoryChainSnapshot: Hashable, Sendable {
    let record: RecordShell
    let artifacts: [Artifact]
    let analysis: RecordAnalysisSnapshot?
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let links: [ArtifactEntityLink]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]

    var isCompleteChain: Bool {
        !artifacts.isEmpty
            && analysis != nil
            && !entities.isEmpty
            && !links.isEmpty
            && !arcs.isEmpty
            && !reflections.isEmpty
    }
}

struct DebugMemoryFixtureSnapshot: Hashable, Sendable {
    let recordID: UUID
    let recordTitle: String
    let chain: DebugMemoryChainSnapshot
}

@MainActor
protocol MoryMemoryRepositorying: AnyObject {
    func createMemory(from draft: MemoryCaptureDraft) throws -> MemorySummary
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot?
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot?
    func search(query: String, limit: Int?) throws -> SearchSnapshot
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary]
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc]
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot]
    func seedDebugFixture() throws -> DebugMemoryFixtureSnapshot
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot?
}

extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstMeaningfulLine: String? {
        split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }
}

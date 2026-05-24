import Foundation

struct SearchMemoryResultSnapshot: Identifiable, Hashable, Sendable {
    let memory: MemorySummary
    let explanations: [SearchMatchExplanation]

    init(memory: MemorySummary, explanations: [SearchMatchExplanation] = []) {
        self.memory = memory
        self.explanations = explanations
    }

    var id: UUID { memory.id }
}

struct SearchEntityResultSnapshot: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemoryCount: Int
    let relatedThemes: [String]
    let relatedPeople: [String]
    let reflectionCount: Int
    let arcCount: Int

    var id: UUID { entity.id }
}

struct SearchArcResultSnapshot: Identifiable, Hashable, Sendable {
    let summary: TemporalArcSummarySnapshot

    var id: UUID { summary.id }
}

struct SearchReflectionResultSnapshot: Identifiable, Hashable, Sendable {
    let summary: ReflectionSummarySnapshot

    var id: UUID { summary.id }
}

enum SearchRetrievalSource: String, Hashable, Sendable {
    case exactFallback
    case graph
    case spotlight
}

enum SearchMatchSource: String, Hashable, Sendable {
    case record
    case artifact
    case entity
    case context
    case spotlight
}

struct SearchMatchExplanation: Identifiable, Hashable, Sendable {
    var id: String {
        [
            source.rawValue,
            artifactID?.uuidString ?? "",
            entityID?.uuidString ?? "",
            label,
            snippet,
        ].joined(separator: "|")
    }

    let source: SearchMatchSource
    let label: String
    let snippet: String
    let artifactID: UUID?
    let entityID: UUID?

    init(
        source: SearchMatchSource,
        label: String,
        snippet: String,
        artifactID: UUID? = nil,
        entityID: UUID? = nil
    ) {
        self.source = source
        self.label = label
        self.snippet = snippet
        self.artifactID = artifactID
        self.entityID = entityID
    }
}

enum SemanticSearchStatus: Hashable, Sendable {
    case notRequested
    case disabled
    case unavailable
    case succeeded(resultCount: Int)
    case failed(String)
}

struct SearchSnapshot: Hashable, Sendable {
    var query: String
    var memories: [SearchMemoryResultSnapshot]
    var entities: [SearchEntityResultSnapshot]
    var arcs: [SearchArcResultSnapshot]
    var reflections: [SearchReflectionResultSnapshot]
    var semanticMemoryIDs: [UUID] = []
    var retrievalSources: [SearchRetrievalSource] = []
    var semanticSearchStatus: SemanticSearchStatus = .notRequested
}

struct SpotlightIndexReport: Hashable, Sendable {
    var indexedItemCount: Int
    var deletedItemCount: Int
    var skippedReason: String?

    static func skipped(_ reason: String) -> SpotlightIndexReport {
        SpotlightIndexReport(indexedItemCount: 0, deletedItemCount: 0, skippedReason: reason)
    }
}

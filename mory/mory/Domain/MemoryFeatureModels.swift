import Foundation

enum CaptureArtifactDraft: Hashable, Sendable, Identifiable {
    case text(title: String?, body: String)
    case photo(title: String?, summary: String, filename: String)
    case audio(title: String?, summary: String, filename: String)
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?)
    case link(title: String?, url: String, note: String?)
    case todo(title: String, note: String?)

    var id: String {
        switch self {
        case let .text(title, body):
            return "text-\(title ?? body)"
        case let .photo(title, summary, _):
            return "photo-\(title ?? summary)"
        case let .audio(title, summary, _):
            return "audio-\(title ?? summary)"
        case let .location(title, summary, _, _):
            return "location-\(title ?? summary)"
        case let .link(title, url, _):
            return "link-\(title ?? url)"
        case let .todo(title, note):
            return "todo-\(title)-\(note ?? "")"
        }
    }

    var captureSummary: String {
        switch self {
        case let .text(title, body):
            return [title?.trimmedOrNil, body.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? body.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Untitled Memory"
        case let .photo(title, summary, filename):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .audio(title, summary, filename):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .location(title, summary, latitude, longitude):
            var components = [title?.trimmedOrNil, summary.trimmedOrNil].compactMap { $0 }
            if let latitude {
                components.append(String(latitude))
            }
            if let longitude {
                components.append(String(longitude))
            }
            return components.joined(separator: " • ").trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? "Location capture"
        case let .link(title, url, note):
            return [title?.trimmedOrNil, note?.trimmedOrNil, url.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? url
        case let .todo(title, note):
            return [title.trimmedOrNil, note?.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? note?.trimmedOrNil
                ?? title
        }
    }
}

struct MemoryCaptureDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var mood: String?
    var inputContext: String?
    var captureSource: CaptureSource
    var artifacts: [CaptureArtifactDraft]

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        captureSource: CaptureSource = .composer,
        artifacts: [CaptureArtifactDraft] = []
    ) {
        self.title = title
        self.rawText = rawText
        self.mood = mood
        self.inputContext = inputContext
        self.captureSource = captureSource
        self.artifacts = artifacts
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

enum CompositionRenderValue: Hashable, Sendable {
    case memory(MemorySummary)
    case arc(TemporalArc)
    case reflection(ReflectionSnapshot)
    case system(title: String, subtitle: String)
}

struct HomeBoardItemSnapshot: Identifiable, Hashable, Sendable {
    let compositionItem: CompositionItem
    let renderValue: CompositionRenderValue

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

struct ThemeMemorySummary: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let relatedPeople: [String]
    let arcCount: Int

    var id: UUID { entity.id }
}

struct GraphEntitySectionSnapshot: Identifiable, Hashable, Sendable {
    let kind: EntityKind
    let entities: [EntityNode]

    var id: String { kind.rawValue }
}

struct GraphOverviewSnapshot: Hashable, Sendable {
    let entitySections: [GraphEntitySectionSnapshot]
    let topEdges: [EntityEdge]
    let people: [PersonMemorySummary]
    let themes: [ThemeMemorySummary]
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
    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot?
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot?
    func search(query: String, limit: Int?) throws -> SearchSnapshot
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary]
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary]
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc]
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot]
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot?
}

protocol RecordAnalysisServing: Sendable {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot
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

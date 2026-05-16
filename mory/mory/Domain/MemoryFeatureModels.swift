import Foundation

enum CaptureArtifactDraft: Hashable, Sendable, Identifiable {
    case text(title: String?, body: String)
    case photo(title: String?, summary: String, filename: String, imageData: Data?, thumbnailData: Data?, ocrText: String = "", photoMetadata: [String: String] = [:])
    case audio(title: String?, summary: String, filename: String, audioData: Data?, transcriptionText: String = "")
    case location(title: String?, summary: String, latitude: Double?, longitude: Double?)
    case link(title: String?, url: String, note: String?)
    case todo(title: String, note: String?)

    var id: String {
        switch self {
        case let .text(title, body):
            return "text-\(title ?? body)"
        case let .photo(title, summary, filename, _, _, _, _):
            return "photo-\(title ?? summary)-\(filename)"
        case let .audio(title, summary, filename, _, _):
            return "audio-\(title ?? summary)-\(filename)"
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
        case let .photo(title, summary, filename, _, _, _, _):
            return [title?.trimmedOrNil, summary.trimmedOrNil, filename.trimmedOrNil].compactMap { $0 }.joined(separator: " • ")
                .trimmedOrNil
                ?? summary.trimmedOrNil
                ?? title?.trimmedOrNil
                ?? filename
        case let .audio(title, summary, filename, _, _):
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
    let pipelineStatus: MemoryPipelineStatusSnapshot?

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
    let pipelineStatus: MemoryPipelineStatusSnapshot?
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]
}

struct MemoryEditDraft: Hashable, Sendable {
    var rawText: String
    var userMood: String?
    var inputContext: String?
    var appendedArtifactText: String?

    init(
        rawText: String,
        userMood: String? = nil,
        inputContext: String? = nil,
        appendedArtifactText: String? = nil
    ) {
        self.rawText = rawText
        self.userMood = userMood
        self.inputContext = inputContext
        self.appendedArtifactText = appendedArtifactText
    }
}

enum MemoryPipelineStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case running
    case completed
    case failed

    var id: String { rawValue }
}

struct MemoryPipelineStatusSnapshot: Identifiable, Hashable, Sendable {
    let recordID: UUID
    let stage: MemoryPipelineStage
    let lastError: String?
    let requestBody: String?
    let responseBody: String?
    let rawErrorBody: String?
    let lastHTTPStatusCode: Int?
    let failedStage: String?
    let lastAttemptAt: Date?
    let completedAt: Date?
    let updatedAt: Date

    var id: UUID { recordID }

    var userLabel: String {
        switch stage {
        case .pending:
            return String(localized: "pipeline.status.pending")
        case .running:
            return String(localized: "pipeline.status.running")
        case .completed:
            return String(localized: "pipeline.status.completed")
        case .failed:
            return String(localized: "pipeline.status.failed")
        }
    }

    var explanation: String {
        switch stage {
        case .pending:
            return String(localized: "pipeline.explain.pending")
        case .running:
            return String(localized: "pipeline.explain.running")
        case .completed:
            return String(localized: "pipeline.explain.completed")
        case .failed:
            return String(localized: "pipeline.explain.failed")
        }
    }
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

struct EntityDetailSnapshot: Identifiable, Hashable, Sendable {
    let entity: EntityNode
    let artifactCount: Int
    let relatedMemories: [MemorySummary]
    let relatedThemes: [String]
    let relatedPeople: [String]
    let relatedReflections: [ReflectionSummarySnapshot]
    let relatedArcs: [TemporalArcSummarySnapshot]
    let edges: [EntityEdge]

    var id: UUID { entity.id }
}

struct SearchMemoryResultSnapshot: Identifiable, Hashable, Sendable {
    let memory: MemorySummary

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

struct SearchSnapshot: Hashable, Sendable {
    var query: String
    var memories: [SearchMemoryResultSnapshot]
    var entities: [SearchEntityResultSnapshot]
    var arcs: [SearchArcResultSnapshot]
    var reflections: [SearchReflectionResultSnapshot]
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

struct TemporalArcSummarySnapshot: Identifiable, Hashable, Sendable {
    let arc: TemporalArc
    let relatedMemories: [MemorySummary]
    let linkedReflection: ReflectionSnapshot?

    var id: UUID { arc.id }
}

struct ReflectionSummarySnapshot: Identifiable, Hashable, Sendable {
    let reflection: ReflectionSnapshot
    let linkedArc: TemporalArc?
    let relatedMemories: [MemorySummary]

    var id: UUID { reflection.id }
}

struct PersonDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: PersonMemorySummary
    let relatedArcs: [TemporalArcSummarySnapshot]
    let relatedReflections: [ReflectionSummarySnapshot]

    var id: UUID { summary.id }
}

struct TemporalArcDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: TemporalArcSummarySnapshot
    let reflections: [ReflectionSummarySnapshot]
    let entityDetails: [EntityDetailSnapshot]
    let mergeCandidate: TemporalArcSummarySnapshot?
    let mergeCandidateOverlapScore: Double?

    var id: UUID { summary.id }
}

struct ReflectionDetailSnapshot: Identifiable, Hashable, Sendable {
    let summary: ReflectionSummarySnapshot
    let linkedArc: TemporalArcSummarySnapshot?
    let entityDetails: [EntityDetailSnapshot]

    var id: UUID { summary.id }
}

struct PipelineStatusSummary: Identifiable, Hashable, Sendable {
    let recordID: UUID
    let title: String
    let status: MemoryPipelineStatusSnapshot

    var id: UUID { recordID }
}

@MainActor
protocol MoryMemoryRepositorying: AnyObject {
    func createMemory(from draft: MemoryCaptureDraft) async throws -> MemorySummary
    func updateMemory(recordID: UUID, draft: MemoryEditDraft) async throws -> MemoryDetailSnapshot?
    func deleteMemory(recordID: UUID) throws
    func refreshMemoryPipeline(recordID: UUID) async throws
    func fetchRecentMemories(limit: Int?) throws -> [MemorySummary]
    func fetchTimeline(granularity: TimelineGranularity, limit: Int?) throws -> TimelineSnapshot
    func fetchHomeBoard(for date: Date, limit: Int) throws -> HomeBoardSnapshot
    func fetchMemoryDetail(recordID: UUID) throws -> MemoryDetailSnapshot?
    func fetchRecordAnalysis(recordID: UUID) throws -> RecordAnalysisSnapshot?
    func fetchPipelineStatus(recordID: UUID) throws -> MemoryPipelineStatusSnapshot?
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary]
    func search(query: String, limit: Int?) throws -> SearchSnapshot
    func fetchEntityDetails(kind: EntityKind, limit: Int?) throws -> [EntityDetailSnapshot]
    func fetchEntityDetail(entityID: UUID) throws -> EntityDetailSnapshot?
    func fetchPeopleSummaries(limit: Int?) throws -> [PersonMemorySummary]
    func fetchPersonDetail(entityID: UUID) throws -> PersonDetailSnapshot?
    func fetchThemeSummaries(limit: Int?) throws -> [ThemeMemorySummary]
    func fetchGraphOverview(limitPerKind: Int?, edgeLimit: Int?) throws -> GraphOverviewSnapshot
    func fetchTemporalArcs(limit: Int?) throws -> [TemporalArc]
    func fetchTemporalArcSummaries(limit: Int?) throws -> [TemporalArcSummarySnapshot]
    func fetchTemporalArcDetail(arcID: UUID) throws -> TemporalArcDetailSnapshot?
    func acceptTemporalArc(arcID: UUID) async throws
    func archiveTemporalArc(arcID: UUID) async throws
    func mergeTemporalArc(arcID: UUID) async throws -> TemporalArcDetailSnapshot?
    func fetchReflections(limit: Int?) throws -> [ReflectionSnapshot]
    func fetchReflectionSummaries(limit: Int?) throws -> [ReflectionSummarySnapshot]
    func fetchReflectionDetail(reflectionID: UUID) throws -> ReflectionDetailSnapshot?
    func saveReflection(reflectionID: UUID) async throws
    func dismissReflection(reflectionID: UUID) async throws
    func archiveReflection(reflectionID: UUID) async throws
    func fetchDebugDiagnostics(targetType: DebugAnalysisTarget, targetID: UUID?) throws -> DebugDiagnosticsSnapshot
    func rerunDebugPipeline(targetType: DebugAnalysisTarget, targetID: UUID?, mode: DebugRebuildMode) async throws
    func seedDebugFixtures(count: Int) async throws -> [DebugMemoryFixtureSnapshot]
    func clearDebugFixtures() throws
    func seedDebugFixture() async throws -> DebugMemoryFixtureSnapshot
    func fetchDebugFixtureSnapshot(recordID: UUID) throws -> DebugMemoryFixtureSnapshot?
}

protocol RecordAnalysisServing: Sendable {
    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference]
    ) async throws -> RecordAnalysisSnapshot

    func generateReflection(
        record: RecordShell,
        artifacts: [Artifact],
        linkedArcID: UUID?,
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func replayReflection(
        reflection: ReflectionSnapshot,
        linkedArc: TemporalArc?,
        record: RecordShell?,
        artifacts: [Artifact],
        knownEntities: [EntityReference],
        prompt: String?
    ) async throws -> ReflectionServiceResult

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot?
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

    func ifEmpty(_ fallback: String) -> String {
        trimmedOrNil ?? fallback
    }
}

struct TimelineDayGroup: Identifiable, Hashable, Sendable {
    let date: Date
    let memories: [MemorySummary]
    var id: Date { date }
    var dayLabel: String { date.formatted(date: .abbreviated, time: .omitted) }
}

enum TimelineGranularity: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }
}

struct TimelineSnapshot: Hashable, Sendable {
    let granularity: TimelineGranularity
    let groups: [TimelineDayGroup]
    let totalCount: Int
}

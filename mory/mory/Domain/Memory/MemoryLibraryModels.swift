import Foundation

struct MemorySummary: Identifiable, Hashable, Sendable {
    let record: RecordShell
    let primaryArtifact: Artifact?
    let contextArtifacts: [Artifact]
    let artifactCount: Int
    let pipelineStatus: MemoryPipelineStatusSnapshot?

    var id: UUID { record.id }

    var title: String {
        record.displayTitle
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
    let artifactSemanticDigests: [ArtifactSemanticDigest]
    let cardArrangement: MemoryCardArrangement?
    let analysis: RecordAnalysisSnapshot?
    let pipelineStatus: MemoryPipelineStatusSnapshot?
    let entities: [EntityNode]
    let edges: [EntityEdge]
    let arcs: [TemporalArc]
    let reflections: [ReflectionSnapshot]
}

struct MemoryEditDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var userMood: String?
    var inputContext: String?
    var appendedArtifactText: String?
    var addedArtifacts: [CaptureArtifactDraft]

    init(
        title: String? = nil,
        rawText: String,
        userMood: String? = nil,
        inputContext: String? = nil,
        appendedArtifactText: String? = nil,
        addedArtifacts: [CaptureArtifactDraft] = []
    ) {
        self.title = title
        self.rawText = rawText
        self.userMood = userMood
        self.inputContext = inputContext
        self.appendedArtifactText = appendedArtifactText
        self.addedArtifacts = addedArtifacts
    }
}

enum MemoryMutationField<Value: Hashable & Sendable>: Hashable, Sendable {
    case unchanged
    case set(Value?)

    var shouldUpdate: Bool {
        if case .set = self { true } else { false }
    }

    var value: Value? {
        if case let .set(value) = self { value } else { nil }
    }
}

struct MemoryMutationRecordPatch: Hashable, Sendable {
    var title: MemoryMutationField<String>
    var rawText: MemoryMutationField<String>
    var userMood: MemoryMutationField<String>
    var inputContext: MemoryMutationField<String>
    var captureSource: MemoryMutationField<CaptureSource>

    init(
        title: MemoryMutationField<String> = .unchanged,
        rawText: MemoryMutationField<String> = .unchanged,
        userMood: MemoryMutationField<String> = .unchanged,
        inputContext: MemoryMutationField<String> = .unchanged,
        captureSource: MemoryMutationField<CaptureSource> = .unchanged
    ) {
        self.title = title
        self.rawText = rawText
        self.userMood = userMood
        self.inputContext = inputContext
        self.captureSource = captureSource
    }

    var hasChanges: Bool {
        title.shouldUpdate
            || rawText.shouldUpdate
            || userMood.shouldUpdate
            || inputContext.shouldUpdate
            || captureSource.shouldUpdate
    }
}

struct MemoryMutationDraft: Hashable, Sendable {
    var recordPatch: MemoryMutationRecordPatch
    var addedArtifacts: [CaptureArtifactDraft]
    var addedCardArrangement: MemoryCardArrangementDraft?
    var updatedArtifacts: [Artifact]
    var deletedArtifactIDs: [UUID]
    var artifactOrder: [UUID]?
    var cardArrangement: MemoryCardArrangement?

    init(
        recordPatch: MemoryMutationRecordPatch = MemoryMutationRecordPatch(),
        addedArtifacts: [CaptureArtifactDraft] = [],
        addedCardArrangement: MemoryCardArrangementDraft? = nil,
        updatedArtifacts: [Artifact] = [],
        deletedArtifactIDs: [UUID] = [],
        artifactOrder: [UUID]? = nil,
        cardArrangement: MemoryCardArrangement? = nil
    ) {
        self.recordPatch = recordPatch
        self.addedArtifacts = addedArtifacts
        self.addedCardArrangement = addedCardArrangement
        self.updatedArtifacts = updatedArtifacts
        self.deletedArtifactIDs = deletedArtifactIDs
        self.artifactOrder = artifactOrder
        self.cardArrangement = cardArrangement
    }

    var hasChanges: Bool {
        recordPatch.hasChanges
            || !addedArtifacts.isEmpty
            || addedCardArrangement != nil
            || !updatedArtifacts.isEmpty
            || !deletedArtifactIDs.isEmpty
            || artifactOrder != nil
            || cardArrangement != nil
    }
}

enum MemoryMutationRefreshPolicy: Hashable, Sendable {
    case saveOnly
    case runImmediately
}

struct MemoryMutationResult: Hashable, Sendable {
    let mutationID: UUID
    let detail: MemoryDetailSnapshot?
    let addedArtifactIDs: [UUID]
    let updatedArtifactIDs: [UUID]
    let deletedArtifactIDs: [UUID]
    let reorderedArtifactIDs: [UUID]
    let invalidatedDerivedData: Bool
    let pipelineStatus: MemoryPipelineStatusSnapshot?
}

enum MemoryPipelineStage: String, Codable, CaseIterable, Identifiable, Sendable {
    case notScheduled
    case pending
    case running
    case completed
    case failed

    var id: String { rawValue }
}

struct MemoryPipelineStatusSnapshot: Identifiable, Hashable, Sendable {
    let recordID: UUID
    let stage: MemoryPipelineStage
    let requestID: String?
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
        case .notScheduled:
            return String(localized: "pipeline.status.notScheduled")
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
        case .notScheduled:
            return String(localized: "pipeline.explain.notScheduled")
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
    case clarificationQuestion(question: ClarificationQuestion, profile: EntityProfile?)
    case yesterdayPanel(title: String, subtitle: String, sourceRecordIDs: [UUID])
    case systemPrompt(title: String, subtitle: String, actionTitle: String?)
    case contextCluster(title: String, subtitle: String, sourceRecordIDs: [UUID])
    case pendingAction(title: String, subtitle: String, targetRecordID: UUID?)
}

struct HomeBoardItemSnapshot: Identifiable, Hashable, Sendable {
    let compositionItem: CompositionItem
    let renderValue: CompositionRenderValue
    let cardKind: HomeBoardCardKind
    let priority: Double
    let reason: String
    let sourceRecordIDs: [UUID]
    let layout: HomeBoardItemLayout
    let isPinned: Bool
    let isHidden: Bool
    let dismissedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var id: UUID { compositionItem.id }
}

struct HomeBoardSnapshot: Hashable, Sendable {
    let board: Board
    let composition: Composition
    let items: [HomeBoardItemSnapshot]

    var userBoardItems: [HomeBoardItemSnapshot] {
        items.filter { $0.layout.layer == .userBoard }
    }

    var suggestionItems: [HomeBoardItemSnapshot] {
        items.filter { $0.layout.layer == .suggestion }
    }
}

struct HomeBoardDebugInputSnapshot: Hashable, Sendable {
    let memoryCount: Int
    let todayMemoryCount: Int
    let recent24HourMemoryCount: Int
    let contextMemoryCount: Int
    let highSalienceMemoryCount: Int
    let graphLinkCount: Int
    let entityCount: Int
    let edgeCount: Int
    let acceptedArcCount: Int
    let activeAcceptedArcCount: Int
    let suggestedReflectionCount: Int
    let savedReflectionCount: Int
    let runningPipelineCount: Int
    let failedPipelineCount: Int
}

struct HomeBoardDebugPreferenceSnapshot: Hashable, Sendable {
    let totalCount: Int
    let pinnedCount: Int
    let hiddenCount: Int
    let dismissedCount: Int
}

struct HomeBoardDebugSnapshot: Hashable, Sendable {
    let generatedAt: Date
    let date: Date
    let limit: Int
    let input: HomeBoardDebugInputSnapshot
    let preferences: HomeBoardDebugPreferenceSnapshot
    let board: HomeBoardSnapshot
}

enum MemoryLibraryContextFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case any
    case hasLocation
    case hasWeather
    case hasMusic

    var id: String { rawValue }
}

enum MemoryLibraryInsightFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case any
    case hasStoryline
    case hasReflection
    case hasEntities

    var id: String { rawValue }
}

struct MemoryLibraryFilter: Hashable, Sendable {
    var dateRange: ClosedRange<Date>?
    var artifactKinds: Set<ArtifactKind>
    var pipelineStages: Set<MemoryPipelineStage>
    var context: MemoryLibraryContextFilter
    var insight: MemoryLibraryInsightFilter

    init(
        dateRange: ClosedRange<Date>? = nil,
        artifactKinds: Set<ArtifactKind> = [],
        pipelineStages: Set<MemoryPipelineStage> = [],
        context: MemoryLibraryContextFilter = .any,
        insight: MemoryLibraryInsightFilter = .any
    ) {
        self.dateRange = dateRange
        self.artifactKinds = artifactKinds
        self.pipelineStages = pipelineStages
        self.context = context
        self.insight = insight
    }

    static var empty: MemoryLibraryFilter { MemoryLibraryFilter() }

    var isActive: Bool {
        dateRange != nil || !artifactKinds.isEmpty || !pipelineStages.isEmpty || context != .any || insight != .any
    }
}

struct MemoryLibraryRowSnapshot: Identifiable, Hashable, Sendable {
    let memory: MemorySummary
    let artifactKinds: [ArtifactKind]
    let hasLocation: Bool
    let hasWeather: Bool
    let hasMusic: Bool
    let relatedStorylineCount: Int
    let relatedReflectionCount: Int
    let entityCount: Int

    var id: UUID { memory.id }
    var hasContext: Bool { hasLocation || hasWeather || hasMusic }
    var hasInsights: Bool { relatedStorylineCount > 0 || relatedReflectionCount > 0 || entityCount > 0 }
}

struct MemoryLibraryDayGroup: Identifiable, Hashable, Sendable {
    let date: Date
    let rows: [MemoryLibraryRowSnapshot]

    var id: Date { date }
    var dayLabel: String { date.formatted(date: .abbreviated, time: .omitted) }
}

struct MemoryLibraryFilterMetadata: Hashable, Sendable {
    let availableArtifactKinds: [ArtifactKind]
    let availablePipelineStages: [MemoryPipelineStage]
    let contextMemoryCount: Int
    let insightMemoryCount: Int
}

struct MemoryLibrarySnapshot: Hashable, Sendable {
    let filter: MemoryLibraryFilter
    let groups: [MemoryLibraryDayGroup]
    let totalCount: Int
    let filteredCount: Int
    let metadata: MemoryLibraryFilterMetadata
}

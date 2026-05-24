import Foundation

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
    let intelligenceProfile: EntityProfile?
    let pendingQuestions: [ClarificationQuestion]

    init(
        entity: EntityNode,
        artifactCount: Int,
        relatedMemories: [MemorySummary],
        relatedThemes: [String],
        relatedPeople: [String],
        relatedReflections: [ReflectionSummarySnapshot],
        relatedArcs: [TemporalArcSummarySnapshot],
        edges: [EntityEdge],
        intelligenceProfile: EntityProfile? = nil,
        pendingQuestions: [ClarificationQuestion] = []
    ) {
        self.entity = entity
        self.artifactCount = artifactCount
        self.relatedMemories = relatedMemories
        self.relatedThemes = relatedThemes
        self.relatedPeople = relatedPeople
        self.relatedReflections = relatedReflections
        self.relatedArcs = relatedArcs
        self.edges = edges
        self.intelligenceProfile = intelligenceProfile
        self.pendingQuestions = pendingQuestions
    }

    var id: UUID { entity.id }
}

enum PlaceProfileMutationError: LocalizedError, Equatable {
    case profileNotFound
    case emptyDisplayName
    case mergeRequiresAtLeastOneOtherProfile
    case mergeCannotIncludePrimary
    case splitRequiresMovingArtifacts
    case splitCannotMoveAllArtifacts
    case splitArtifactsNotInProfile
    case splitArtifactsMustBeLocations

    var errorDescription: String? {
        switch self {
        case .profileNotFound:
            "Place profile was not found."
        case .emptyDisplayName:
            "Place name cannot be empty."
        case .mergeRequiresAtLeastOneOtherProfile:
            "Choose at least one other place to merge."
        case .mergeCannotIncludePrimary:
            "A place cannot be merged into itself."
        case .splitRequiresMovingArtifacts:
            "Choose at least one location artifact to split."
        case .splitCannotMoveAllArtifacts:
            "A split must leave at least one location artifact in the original place."
        case .splitArtifactsNotInProfile:
            "Selected artifacts are not linked to this place."
        case .splitArtifactsMustBeLocations:
            "Only location artifacts can be split into a place profile."
        }
    }
}

enum PersonEntityMutationError: LocalizedError, Equatable {
    case entityNotFound
    case entityIsNotPerson
    case emptyDisplayName
    case mergeRequiresAtLeastOneOtherEntity
    case mergeCannotIncludePrimary
    case splitRequiresMovingRecords
    case splitCannotMoveAllRecords
    case splitRecordsNotInEntity

    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            "Person entity was not found."
        case .entityIsNotPerson:
            "Selected entity is not a person."
        case .emptyDisplayName:
            "Person name cannot be empty."
        case .mergeRequiresAtLeastOneOtherEntity:
            "Choose at least one other person to merge."
        case .mergeCannotIncludePrimary:
            "A person cannot be merged into itself."
        case .splitRequiresMovingRecords:
            "Choose at least one source memory to split."
        case .splitCannotMoveAllRecords:
            "A split must leave at least one memory on the original person."
        case .splitRecordsNotInEntity:
            "Selected memories are not linked to this person."
        }
    }
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

struct InsightsPresentationSnapshot: Hashable, Sendable {
    let highlightedStoryline: TemporalArcSummarySnapshot?
    let storylines: [TemporalArcSummarySnapshot]
    let suggestedReflections: [ReflectionSummarySnapshot]
    let savedReflections: [ReflectionSummarySnapshot]
    let people: [EntityDetailSnapshot]
    let places: [EntityDetailSnapshot]
    let themes: [EntityDetailSnapshot]
    let decisions: [EntityDetailSnapshot]
    let topEdges: [EntityEdge]
    let totalStorylineCount: Int
    let totalReflectionCount: Int
    let totalEntityCount: Int
}

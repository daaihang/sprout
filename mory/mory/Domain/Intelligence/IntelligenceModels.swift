import Foundation

enum IntelligenceConfirmationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case inferred
    case suggested
    case userConfirmed
    case userRejected
    case stale

    var id: String { rawValue }
}

enum EntityRelationshipToUser: String, Codable, CaseIterable, Identifiable, Sendable {
    case family
    case partner
    case friend
    case coworker
    case manager
    case directReport
    case classmate
    case client
    case acquaintance
    case creator
    case publicFigure
    case other
    case unknown

    var id: String { rawValue }
}

struct EntityProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entityID: UUID
    var kind: EntityKind
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var relationshipToUser: EntityRelationshipToUser?
    var userDescription: String?
    var mentionCount: Int
    var firstMentionedAt: Date?
    var lastMentionedAt: Date?
    var commonContextLabels: [String]
    var sourceRecordIDs: [UUID]
    var confirmationState: IntelligenceConfirmationState
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        entityID: UUID,
        kind: EntityKind,
        displayName: String,
        canonicalName: String? = nil,
        aliases: [String] = [],
        relationshipToUser: EntityRelationshipToUser? = nil,
        userDescription: String? = nil,
        mentionCount: Int = 0,
        firstMentionedAt: Date? = nil,
        lastMentionedAt: Date? = nil,
        commonContextLabels: [String] = [],
        sourceRecordIDs: [UUID] = [],
        confirmationState: IntelligenceConfirmationState = .inferred,
        confidence: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityID = entityID
        self.kind = kind
        self.displayName = displayName
        self.canonicalName = canonicalName ?? displayName
        self.aliases = aliases
        self.relationshipToUser = relationshipToUser
        self.userDescription = userDescription
        self.mentionCount = mentionCount
        self.firstMentionedAt = firstMentionedAt
        self.lastMentionedAt = lastMentionedAt
        self.commonContextLabels = commonContextLabels
        self.sourceRecordIDs = sourceRecordIDs
        self.confirmationState = confirmationState
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct PlaceProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var entityID: UUID
    var displayName: String
    var canonicalName: String
    var aliases: [String]
    var centroidLatitude: Double?
    var centroidLongitude: Double?
    var radiusMeters: Double
    var mentionCount: Int
    var sourceArtifactIDs: [UUID]
    var sourceRecordIDs: [UUID]
    var confirmationState: IntelligenceConfirmationState
    var confidence: Double?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        entityID: UUID = UUID(),
        displayName: String,
        canonicalName: String? = nil,
        aliases: [String] = [],
        centroidLatitude: Double? = nil,
        centroidLongitude: Double? = nil,
        radiusMeters: Double = 120,
        mentionCount: Int = 0,
        sourceArtifactIDs: [UUID] = [],
        sourceRecordIDs: [UUID] = [],
        confirmationState: IntelligenceConfirmationState = .inferred,
        confidence: Double? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityID = entityID
        self.displayName = displayName
        self.canonicalName = canonicalName ?? displayName
        self.aliases = aliases
        self.centroidLatitude = centroidLatitude
        self.centroidLongitude = centroidLongitude
        self.radiusMeters = radiusMeters
        self.mentionCount = mentionCount
        self.sourceArtifactIDs = sourceArtifactIDs
        self.sourceRecordIDs = sourceRecordIDs
        self.confirmationState = confirmationState
        self.confidence = confidence
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum ClarificationQuestionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case entityRelationship
    case entityAlias
    case entityMerge
    case placeMeaning
    case themeConfirmation
    case decisionStatus
    case chapterCandidate
    case dailyReflection
    case revisit

    var id: String { rawValue }
}

enum ClarificationTargetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case record
    case artifact
    case question
    case entity
    case place
    case theme
    case decision
    case chapter
    case reflection

    var id: String { rawValue }
}

enum QuestionSensitivity: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case personal
    case sensitive

    var id: String { rawValue }
}

enum ClarificationQuestionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case answered
    case dismissed
    case expired
    case stale

    var id: String { rawValue }
}

struct ClarificationAnswerOption: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var label: String
    var value: String

    init(id: String? = nil, label: String, value: String? = nil) {
        self.id = id ?? (value ?? label)
        self.label = label
        self.value = value ?? label
    }
}

struct ClarificationAnswer: Codable, Hashable, Sendable {
    var value: String
    var freeformText: String?
    var answeredAt: Date

    init(value: String, freeformText: String? = nil, answeredAt: Date = .now) {
        self.value = value
        self.freeformText = freeformText
        self.answeredAt = answeredAt
    }
}

struct ClarificationQuestion: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: ClarificationQuestionKind
    var prompt: String
    var targetType: ClarificationTargetType
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var candidateAnswers: [ClarificationAnswerOption]
    var priority: Double
    var reason: String
    var sensitivity: QuestionSensitivity
    var status: ClarificationQuestionStatus
    var answer: ClarificationAnswer?
    var createdAt: Date
    var expiresAt: Date?
    var answeredAt: Date?
    var dismissedAt: Date?
    var askCount: Int

    init(
        id: UUID = UUID(),
        kind: ClarificationQuestionKind,
        prompt: String,
        targetType: ClarificationTargetType,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        sourceArtifactIDs: [UUID] = [],
        candidateAnswers: [ClarificationAnswerOption] = [],
        priority: Double = 0,
        reason: String,
        sensitivity: QuestionSensitivity = .normal,
        status: ClarificationQuestionStatus = .pending,
        answer: ClarificationAnswer? = nil,
        createdAt: Date = .now,
        expiresAt: Date? = nil,
        answeredAt: Date? = nil,
        dismissedAt: Date? = nil,
        askCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.targetType = targetType
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.candidateAnswers = candidateAnswers
        self.priority = priority
        self.reason = reason
        self.sensitivity = sensitivity
        self.status = status
        self.answer = answer
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.answeredAt = answeredAt
        self.dismissedAt = dismissedAt
        self.askCount = askCount
    }
}

enum IntelligenceJobKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case postAnalysis
    case entityEnrichment
    case clarificationQuestionGeneration
    case graphDeltaApplication
    case dailyQuestion
    case semanticIndex
    case notificationIntent
    case chapterCandidate

    var id: String { rawValue }
}

enum IntelligenceTargetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case record
    case artifact
    case entity
    case question
    case graphDelta
    case board
    case searchIndex
    case notification

    var id: String { rawValue }
}

enum IntelligenceJobStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case pending
    case running
    case completed
    case failed
    case cancelled

    var id: String { rawValue }
}

struct IntelligenceJob: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: IntelligenceJobKind
    var targetType: IntelligenceTargetType
    var targetID: UUID
    var status: IntelligenceJobStatus
    var priority: Double
    var attemptCount: Int
    var lastError: String?
    var scheduledAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var updatedAt: Date
    var dedupeKey: String
    var requiresCloudAI: Bool

    init(
        id: UUID = UUID(),
        kind: IntelligenceJobKind,
        targetType: IntelligenceTargetType,
        targetID: UUID,
        status: IntelligenceJobStatus = .pending,
        priority: Double = 0,
        attemptCount: Int = 0,
        lastError: String? = nil,
        scheduledAt: Date = .now,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date = .now,
        dedupeKey: String? = nil,
        requiresCloudAI: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.status = status
        self.priority = priority
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.dedupeKey = dedupeKey ?? "\(kind.rawValue):\(targetType.rawValue):\(targetID.uuidString)"
        self.requiresCloudAI = requiresCloudAI
    }
}

enum GraphDeltaSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case localRule
    case localModel
    case cloudAI
    case userAnswer
    case systemMigration

    var id: String { rawValue }
}

enum GraphDeltaOperationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case addAlias
    case setRelationship
    case mergeEntity
    case addEdge
    case updateEdgeWeight
    case createChapterCandidate
    case markDecisionStatus

    var id: String { rawValue }
}

struct GraphDeltaOperation: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: GraphDeltaOperationKind
    var targetType: ClarificationTargetType
    var targetID: UUID
    var relatedID: UUID?
    var stringValue: String?
    var numericValue: Double?
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: GraphDeltaOperationKind,
        targetType: ClarificationTargetType,
        targetID: UUID,
        relatedID: UUID? = nil,
        stringValue: String? = nil,
        numericValue: Double? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.targetType = targetType
        self.targetID = targetID
        self.relatedID = relatedID
        self.stringValue = stringValue
        self.numericValue = numericValue
        self.metadata = metadata
    }
}

struct GraphDelta: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var source: GraphDeltaSource
    var operations: [GraphDeltaOperation]
    var confidence: Double?
    var requiresUserConfirmation: Bool
    var appliedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        source: GraphDeltaSource,
        operations: [GraphDeltaOperation],
        confidence: Double? = nil,
        requiresUserConfirmation: Bool = true,
        appliedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.source = source
        self.operations = operations
        self.confidence = confidence
        self.requiresUserConfirmation = requiresUserConfirmation
        self.appliedAt = appliedAt
        self.createdAt = createdAt
    }
}

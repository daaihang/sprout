import Foundation
import SwiftData

@Model
final class ClarificationQuestionStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var prompt: String
    var targetTypeRawValue: String
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var sourceArtifactIDs: [UUID]
    var candidateAnswersData: Data?
    var priority: Double
    var reason: String
    var sensitivityRawValue: String
    var statusRawValue: String
    var answerData: Data?
    var createdAt: Date
    var expiresAt: Date?
    var answeredAt: Date?
    var dismissedAt: Date?
    var askCount: Int

    init(
        id: UUID,
        kindRawValue: String,
        prompt: String,
        targetTypeRawValue: String,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        sourceArtifactIDs: [UUID] = [],
        candidateAnswersData: Data? = nil,
        priority: Double,
        reason: String,
        sensitivityRawValue: String,
        statusRawValue: String,
        answerData: Data? = nil,
        createdAt: Date,
        expiresAt: Date? = nil,
        answeredAt: Date? = nil,
        dismissedAt: Date? = nil,
        askCount: Int
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.prompt = prompt
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.sourceArtifactIDs = sourceArtifactIDs
        self.candidateAnswersData = candidateAnswersData
        self.priority = priority
        self.reason = reason
        self.sensitivityRawValue = sensitivityRawValue
        self.statusRawValue = statusRawValue
        self.answerData = answerData
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.answeredAt = answeredAt
        self.dismissedAt = dismissedAt
        self.askCount = askCount
    }
}

@Model
final class IntelligenceJobStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var statusRawValue: String
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
        id: UUID,
        kindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        statusRawValue: String,
        priority: Double,
        attemptCount: Int,
        lastError: String? = nil,
        scheduledAt: Date,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date,
        dedupeKey: String,
        requiresCloudAI: Bool
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.statusRawValue = statusRawValue
        self.priority = priority
        self.attemptCount = attemptCount
        self.lastError = lastError
        self.scheduledAt = scheduledAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.dedupeKey = dedupeKey
        self.requiresCloudAI = requiresCloudAI
    }
}

@Model
final class GraphDeltaStore {
    @Attribute(.unique) var id: UUID
    var sourceRawValue: String
    var operationsData: Data?
    var confidence: Double?
    var requiresUserConfirmation: Bool
    var appliedAt: Date?
    var createdAt: Date

    init(
        id: UUID,
        sourceRawValue: String,
        operationsData: Data?,
        confidence: Double? = nil,
        requiresUserConfirmation: Bool,
        appliedAt: Date? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.sourceRawValue = sourceRawValue
        self.operationsData = operationsData
        self.confidence = confidence
        self.requiresUserConfirmation = requiresUserConfirmation
        self.appliedAt = appliedAt
        self.createdAt = createdAt
    }
}

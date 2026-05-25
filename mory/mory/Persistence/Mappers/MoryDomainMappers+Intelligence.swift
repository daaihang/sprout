import Foundation

@MainActor
extension ClarificationQuestionStore {
    convenience init(domainModel: ClarificationQuestion) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            prompt: domainModel.prompt,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            sourceArtifactIDs: domainModel.sourceArtifactIDs,
            candidateAnswersData: PersistenceCoding.encode(domainModel.candidateAnswers),
            priority: domainModel.priority,
            reason: domainModel.reason,
            sensitivityRawValue: domainModel.sensitivity.rawValue,
            statusRawValue: domainModel.status.rawValue,
            answerData: PersistenceCoding.encode(domainModel.answer),
            createdAt: domainModel.createdAt,
            expiresAt: domainModel.expiresAt,
            answeredAt: domainModel.answeredAt,
            dismissedAt: domainModel.dismissedAt,
            askCount: domainModel.askCount
        )
    }

    var domainModel: ClarificationQuestion {
        ClarificationQuestion(
            id: id,
            kind: ClarificationQuestionKind(rawValue: kindRawValue) ?? .dailyReflection,
            prompt: prompt,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs,
            sourceArtifactIDs: sourceArtifactIDs,
            candidateAnswers: PersistenceCoding.decode([ClarificationAnswerOption].self, from: candidateAnswersData) ?? [],
            priority: priority,
            reason: reason,
            sensitivity: QuestionSensitivity(rawValue: sensitivityRawValue) ?? .normal,
            status: ClarificationQuestionStatus(rawValue: statusRawValue) ?? .pending,
            answer: PersistenceCoding.decode(ClarificationAnswer.self, from: answerData),
            createdAt: createdAt,
            expiresAt: expiresAt,
            answeredAt: answeredAt,
            dismissedAt: dismissedAt,
            askCount: askCount
        )
    }

    func apply(domainModel: ClarificationQuestion) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        prompt = domainModel.prompt
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        sourceRecordIDs = domainModel.sourceRecordIDs
        sourceArtifactIDs = domainModel.sourceArtifactIDs
        candidateAnswersData = PersistenceCoding.encode(domainModel.candidateAnswers)
        priority = domainModel.priority
        reason = domainModel.reason
        sensitivityRawValue = domainModel.sensitivity.rawValue
        statusRawValue = domainModel.status.rawValue
        answerData = PersistenceCoding.encode(domainModel.answer)
        createdAt = domainModel.createdAt
        expiresAt = domainModel.expiresAt
        answeredAt = domainModel.answeredAt
        dismissedAt = domainModel.dismissedAt
        askCount = domainModel.askCount
    }
}

@MainActor
extension IntelligenceJobStore {
    convenience init(domainModel: IntelligenceJob) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            statusRawValue: domainModel.status.rawValue,
            priority: domainModel.priority,
            attemptCount: domainModel.attemptCount,
            lastError: domainModel.lastError,
            scheduledAt: domainModel.scheduledAt,
            startedAt: domainModel.startedAt,
            completedAt: domainModel.completedAt,
            updatedAt: domainModel.updatedAt,
            dedupeKey: domainModel.dedupeKey,
            requiresCloudAI: domainModel.requiresCloudAI
        )
    }

    var domainModel: IntelligenceJob {
        IntelligenceJob(
            id: id,
            kind: IntelligenceJobKind(rawValue: kindRawValue) ?? .postAnalysis,
            targetType: IntelligenceTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            status: IntelligenceJobStatus(rawValue: statusRawValue) ?? .pending,
            priority: priority,
            attemptCount: attemptCount,
            lastError: lastError,
            scheduledAt: scheduledAt,
            startedAt: startedAt,
            completedAt: completedAt,
            updatedAt: updatedAt,
            dedupeKey: dedupeKey,
            requiresCloudAI: requiresCloudAI
        )
    }

    func apply(domainModel: IntelligenceJob) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        statusRawValue = domainModel.status.rawValue
        priority = domainModel.priority
        attemptCount = domainModel.attemptCount
        lastError = domainModel.lastError
        scheduledAt = domainModel.scheduledAt
        startedAt = domainModel.startedAt
        completedAt = domainModel.completedAt
        updatedAt = domainModel.updatedAt
        dedupeKey = domainModel.dedupeKey
        requiresCloudAI = domainModel.requiresCloudAI
    }
}

@MainActor
extension GraphDeltaStore {
    convenience init(domainModel: GraphDelta) {
        self.init(
            id: domainModel.id,
            sourceRawValue: domainModel.source.rawValue,
            operationsData: PersistenceCoding.encode(domainModel.operations),
            confidence: domainModel.confidence,
            requiresUserConfirmation: domainModel.requiresUserConfirmation,
            appliedAt: domainModel.appliedAt,
            createdAt: domainModel.createdAt
        )
    }

    var domainModel: GraphDelta {
        GraphDelta(
            id: id,
            source: GraphDeltaSource(rawValue: sourceRawValue) ?? .localRule,
            operations: PersistenceCoding.decode([GraphDeltaOperation].self, from: operationsData) ?? [],
            confidence: confidence,
            requiresUserConfirmation: requiresUserConfirmation,
            appliedAt: appliedAt,
            createdAt: createdAt
        )
    }

    func apply(domainModel: GraphDelta) {
        id = domainModel.id
        sourceRawValue = domainModel.source.rawValue
        operationsData = PersistenceCoding.encode(domainModel.operations)
        confidence = domainModel.confidence
        requiresUserConfirmation = domainModel.requiresUserConfirmation
        appliedAt = domainModel.appliedAt
        createdAt = domainModel.createdAt
    }
}

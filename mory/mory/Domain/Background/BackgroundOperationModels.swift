import Foundation

enum BackgroundTriggerKind: String, Codable, CaseIterable, Hashable, Sendable {
    case appLaunch
    case sceneForeground
    case homeForegroundRefresh
    case bgProcessingTask
    case bgAppRefreshTask
    case silentPush
    case pipelineCompleted
    case apnsTokenUpdated
    case notificationPreferencesChanged
    case backgroundURLSessionCompleted
    case debugManual
}

struct BackgroundTrigger: Hashable, Sendable {
    var kind: BackgroundTriggerKind
    var targetID: UUID?
    var source: String?
    var metadata: [String: String]

    init(
        kind: BackgroundTriggerKind,
        targetID: UUID? = nil,
        source: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.kind = kind
        self.targetID = targetID
        self.source = source
        self.metadata = metadata
    }
}

enum BackgroundOperationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case recoverUnfinishedJobs
    case processDueJobs
    case prepareDailyQuestion
    case orchestrateNotifications
    case syncRemotePushRegistration
    case flushRemotePushWritebacks
    case scheduleBGTasks
    case recordBackgroundURLSession
}

enum BackgroundOperationStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case pending
    case running
    case completed
    case skipped
    case failed
    case cancelled
}

struct BackgroundOperationRun: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var triggerKind: BackgroundTriggerKind
    var triggerTargetID: UUID?
    var status: BackgroundOperationStatus
    var startedAt: Date
    var completedAt: Date?
    var source: String?
    var summary: String?
    var errors: [String]
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        triggerKind: BackgroundTriggerKind,
        triggerTargetID: UUID? = nil,
        status: BackgroundOperationStatus = .running,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        source: String? = nil,
        summary: String? = nil,
        errors: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.triggerKind = triggerKind
        self.triggerTargetID = triggerTargetID
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.source = source
        self.summary = summary
        self.errors = errors
        self.metadata = metadata
    }
}

struct BackgroundOperationEvent: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var runID: UUID
    var operationKind: BackgroundOperationKind
    var status: BackgroundOperationStatus
    var targetType: String?
    var targetID: UUID?
    var startedAt: Date
    var completedAt: Date?
    var message: String?
    var error: String?
    var resultCounts: [String: Int]

    init(
        id: UUID = UUID(),
        runID: UUID,
        operationKind: BackgroundOperationKind,
        status: BackgroundOperationStatus = .running,
        targetType: String? = nil,
        targetID: UUID? = nil,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        message: String? = nil,
        error: String? = nil,
        resultCounts: [String: Int] = [:]
    ) {
        self.id = id
        self.runID = runID
        self.operationKind = operationKind
        self.status = status
        self.targetType = targetType
        self.targetID = targetID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.message = message
        self.error = error
        self.resultCounts = resultCounts
    }
}

struct BackgroundOperationOutcome: Hashable, Sendable {
    var status: BackgroundOperationStatus
    var message: String?
    var error: String?
    var resultCounts: [String: Int]

    init(
        status: BackgroundOperationStatus,
        message: String? = nil,
        error: String? = nil,
        resultCounts: [String: Int] = [:]
    ) {
        self.status = status
        self.message = message
        self.error = error
        self.resultCounts = resultCounts
    }

    static func completed(
        message: String? = nil,
        resultCounts: [String: Int] = [:]
    ) -> BackgroundOperationOutcome {
        BackgroundOperationOutcome(status: .completed, message: message, resultCounts: resultCounts)
    }

    static func skipped(
        message: String,
        resultCounts: [String: Int] = [:]
    ) -> BackgroundOperationOutcome {
        BackgroundOperationOutcome(status: .skipped, message: message, resultCounts: resultCounts)
    }

    static func failed(
        error: String,
        resultCounts: [String: Int] = [:]
    ) -> BackgroundOperationOutcome {
        BackgroundOperationOutcome(status: .failed, error: error, resultCounts: resultCounts)
    }
}

struct BackgroundOperationReport: Hashable, Sendable {
    var runID: UUID
    var triggerKind: BackgroundTriggerKind
    var operationEvents: [BackgroundOperationEvent] = []
    var errors: [String] = []

    var status: BackgroundOperationStatus {
        errors.isEmpty ? .completed : .failed
    }
}

struct BackgroundOperationSnapshot: Hashable, Sendable {
    var runs: [BackgroundOperationRun]
    var events: [BackgroundOperationEvent]
}

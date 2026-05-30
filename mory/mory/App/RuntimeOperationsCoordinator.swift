import Foundation

struct RuntimeOperationsSnapshot: Hashable, Sendable {
    var generatedAt: Date
    var backgroundRuns: [BackgroundOperationRun]
    var backgroundEvents: [BackgroundOperationEvent]
    var jobQueue: DebugJobQueueSnapshot
    var pipelineStatuses: [PipelineStatusSummary]
    var notifications: NotificationManagementSnapshot
    var push: RemotePushDebugSnapshot
}

struct RuntimeOperationResult: Hashable, Sendable {
    var label: String
    var message: String
}

struct RuntimeNotificationInteractionResult: Hashable, Sendable {
    var route: NotificationInteractionRoute?
    var message: String
}

@MainActor
protocol RuntimeOperationsRepositorying:
    AnyObject,
    BackgroundRuntimeRepositorying,
    NotificationIntentRepositorying,
    NotificationManagementEventRepositorying {
    func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob]
    func fetchGraphDeltas(applied: Bool?, limit: Int?) throws -> [GraphDelta]
    func fetchPipelineStatusSummaries(limit: Int?) throws -> [PipelineStatusSummary]
}

extension MoryMemoryRepository: RuntimeOperationsRepositorying {}

@MainActor
struct RuntimeOperationsCoordinator {
    private let backgroundOperationOrchestrator: BackgroundOperationOrchestrator
    private let notificationOrchestrator: NotificationOrchestrator
    private let remotePushSyncService: any RemotePushSyncing

    init(
        backgroundOperationOrchestrator: BackgroundOperationOrchestrator,
        notificationOrchestrator: NotificationOrchestrator,
        remotePushSyncService: any RemotePushSyncing
    ) {
        self.backgroundOperationOrchestrator = backgroundOperationOrchestrator
        self.notificationOrchestrator = notificationOrchestrator
        self.remotePushSyncService = remotePushSyncService
    }

    func loadSnapshot(repository: any RuntimeOperationsRepositorying, now: Date = .now) async throws -> RuntimeOperationsSnapshot {
        let jobs = try repository.fetchIntelligenceJobs(status: nil, limit: nil)
            .sorted { $0.updatedAt > $1.updatedAt }
        let graphDeltas = try repository.fetchGraphDeltas(applied: nil, limit: nil)
            .sorted { $0.createdAt > $1.createdAt }
        let allIntents = try repository.fetchNotificationIntents(status: nil, limit: nil)
        let intents = Array(allIntents.prefix(160))
        let notificationEvents = try repository.fetchNotificationManagementEvents(kind: nil, limit: 240)
        let pushIntentCounts = RemotePushDebugIntentCounts(
            pendingIntentCount: allIntents.filter { $0.status == .pending }.count,
            scheduledIntentCount: allIntents.filter { $0.status == .scheduled }.count,
            remoteIntentCount: allIntents.filter { $0.deliveryChannel == .remote }.count
        )

        return RuntimeOperationsSnapshot(
            generatedAt: now,
            backgroundRuns: try repository.fetchBackgroundOperationRuns(status: nil, limit: 50),
            backgroundEvents: try repository.fetchBackgroundOperationEvents(runID: nil, limit: 100),
            jobQueue: DebugJobQueueSnapshot(generatedAt: now, jobs: jobs, graphDeltas: graphDeltas),
            pipelineStatuses: try repository.fetchPipelineStatusSummaries(limit: 50),
            notifications: NotificationManagementSnapshot.build(intents: intents, events: notificationEvents),
            push: await remotePushSyncService.fetchDebugSnapshot(intentCounts: pushIntentCounts)
        )
    }

    func runBackground(
        kind: BackgroundTriggerKind,
        source: String,
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async -> RuntimeOperationResult {
        let report = await backgroundOperationOrchestrator.handle(
            trigger: BackgroundTrigger(kind: kind, source: source),
            repository: repository,
            now: now
        )
        return RuntimeOperationResult(
            label: kind.rawValue,
            message: [
                "run=\(report.runID.uuidString.prefix(8))",
                "status=\(report.status.rawValue)",
                "events=\(report.operationEvents.count)",
                "errors=\(report.errors.count)",
            ].joined(separator: " ")
        )
    }

    func runDebugNotification(
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async throws -> RuntimeOperationResult {
        let intent = NotificationIntent(
            kind: .debugTest,
            title: "Mory",
            body: "Debug notification test.",
            privacyLevel: .generic,
            targetType: .record,
            targetID: UUID(),
            scheduledAt: now.addingTimeInterval(3),
            deliveryChannel: .local,
            deepLink: "mory://home",
            reason: "Manual debug notification test.",
            sourceTrigger: .debugManual,
            createdBy: .debug
        )
        let report = try await notificationOrchestrator.orchestrate(
            trigger: .debugManual(intent: intent),
            repository: repository,
            now: now
        )
        return RuntimeOperationResult(
            label: "debugNotification",
            message: [
                "generated=\(report.generatedIntentIDs.count)",
                "deduped=\(report.dedupedIntentIDs.count)",
                "blocked=\(report.blockedIntentIDs.count)",
                "scheduled=\(report.scheduledIntentIDs.count)",
                "remote=\(report.remoteEnqueuedIntentIDs.count)",
                "errors=\(report.errors.count)",
            ].joined(separator: " ")
        )
    }

    func forcePushRegistration(repository: any MoryMemoryRepositorying) async -> RuntimeOperationResult {
        remotePushSyncService.registerSystemRemoteNotificationsIfNeeded(repository: repository)
        await remotePushSyncService.syncRegistrationIfPossible(repository: repository, force: true)
        return RuntimeOperationResult(label: "pushRegistration", message: "Remote push registration sync requested.")
    }

    func loadPushServerMetrics() async throws -> RuntimeOperationResult {
        RuntimeOperationResult(
            label: "pushServerMetrics",
            message: try await remotePushSyncService.fetchServerMetricsText()
        )
    }

    func handleNotificationInteraction(
        _ event: NotificationInteractionEvent,
        repository: any MoryMemoryRepositorying,
        now: Date = .now
    ) async throws -> RuntimeNotificationInteractionResult {
        let interaction = try NotificationInteractionService().handle(
            event: event,
            repository: repository,
            now: now
        )
        await remotePushSyncService.writeBackInteraction(event)
        return RuntimeNotificationInteractionResult(
            route: interaction.route,
            message: "handled=\(event.action.rawValue) route=\(interaction.route != nil)"
        )
    }
}

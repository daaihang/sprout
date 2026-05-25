import Foundation
import BackgroundTasks

enum BackgroundTaskIdentifier {
    static let process = "dev.mory.intelligence.process"
    static let refresh = "dev.mory.intelligence.refresh"
}

@MainActor
final class BackgroundTaskCoordinator {
    private(set) var repository: (any MoryMemoryRepositorying)?
    private var cloudService: (any CloudIntelligenceServing)?
    private var remotePushSyncService: (any RemotePushSyncing)?
    private var notificationOrchestrator: NotificationOrchestrator?

    private let jobWorker = IntelligenceJobWorker()

    // MARK: - Registration (must be called before first runloop in AppDelegate)

    func registerTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.process,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                self?.handleProcessingTask(task)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifier.refresh,
            using: nil
        ) { [weak self] task in
            guard let task = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor [weak self] in
                self?.handleRefreshTask(task)
            }
        }
    }

    // MARK: - Configuration

    func configure(
        repository: any MoryMemoryRepositorying,
        cloudService: (any CloudIntelligenceServing)?,
        remotePushSyncService: (any RemotePushSyncing)? = nil,
        notificationOrchestrator: NotificationOrchestrator? = nil
    ) {
        self.repository = repository
        self.cloudService = cloudService
        self.remotePushSyncService = remotePushSyncService
        self.notificationOrchestrator = notificationOrchestrator
    }

    // MARK: - Schedule

    func scheduleIfNeeded() {
        scheduleProcess()
        scheduleRefresh()
    }

    func orchestrateNotifications(
        trigger: NotificationTrigger,
        now: Date = .now
    ) async throws -> NotificationOrchestrationReport {
        guard let repository else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try await resolvedNotificationOrchestrator.orchestrate(
            trigger: trigger,
            repository: repository,
            now: now
        )
    }

    // MARK: - Handlers

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleProcess()
        guard let repo = repository, let svc = cloudService else {
            task.setTaskCompleted(success: false)
            return
        }
        let t = Task { @MainActor in
            _ = await self.jobWorker.processDueJobs(
                repository: repo,
                cloudIntelligenceService: svc,
                remotePushSyncService: self.remotePushSyncService,
                notificationOrchestrator: self.resolvedNotificationOrchestrator
            )
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { t.cancel() }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        guard let repo = repository else {
            task.setTaskCompleted(success: false)
            return
        }
        let t = Task { @MainActor in
            _ = try? await self.resolvedNotificationOrchestrator.orchestrate(
                trigger: .backgroundRefresh,
                repository: repo
            )
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { t.cancel() }
    }

    private var resolvedNotificationOrchestrator: NotificationOrchestrator {
        notificationOrchestrator ?? .localDelivery
    }

    // MARK: - Private schedule helpers

    private func scheduleProcess() {
        let request = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifier.process)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifier.refresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

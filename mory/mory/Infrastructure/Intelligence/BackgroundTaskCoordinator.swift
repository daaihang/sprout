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

    func configure(repository: any MoryMemoryRepositorying, cloudService: (any CloudIntelligenceServing)?) {
        self.repository = repository
        self.cloudService = cloudService
    }

    // MARK: - Schedule

    func scheduleIfNeeded() {
        scheduleProcess()
        scheduleRefresh()
    }

    // MARK: - Handlers

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleProcess()
        guard let repo = repository, let svc = cloudService else {
            task.setTaskCompleted(success: false)
            return
        }
        let worker = IntelligenceJobWorker()
        let t = Task { @MainActor in
            _ = await worker.processDueJobs(
                repository: repo,
                cloudIntelligenceService: svc
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
        let prep = NotificationIntentPreparationService()
        let scheduler = LocalNotificationScheduler()
        let t = Task { @MainActor in
            _ = try? prep.prepareNextIntentIfNeeded(repository: repo)
            _ = try? await scheduler.schedulePendingIntents(
                repository: repo,
                requestAuthorizationIfNeeded: false
            )
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { t.cancel() }
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

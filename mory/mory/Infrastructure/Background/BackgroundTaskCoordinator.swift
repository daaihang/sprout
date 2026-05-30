import Foundation
import BackgroundTasks

enum BackgroundTaskIdentifier {
    static let process = "dev.mory.intelligence.process"
    static let refresh = "dev.mory.intelligence.refresh"
}

@MainActor
// BGTaskScheduler adapter; operation ownership lives in BackgroundOperationOrchestrator.
final class BackgroundTaskCoordinator {
    private(set) var repository: (any MoryMemoryRepositorying)?
    private var backgroundOrchestrator: BackgroundOperationOrchestrator

    init(backgroundOrchestrator: BackgroundOperationOrchestrator? = nil) {
        self.backgroundOrchestrator = backgroundOrchestrator ?? .noop
    }

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
        backgroundOrchestrator: BackgroundOperationOrchestrator
    ) {
        self.repository = repository
        self.backgroundOrchestrator = backgroundOrchestrator
    }

    // MARK: - Schedule

    func scheduleIfNeeded() {
        scheduleProcess()
        scheduleRefresh()
    }

    func handle(
        trigger: BackgroundTrigger,
        now: Date = .now
    ) async -> BackgroundOperationReport? {
        guard let repository else {
            return nil
        }
        return await backgroundOrchestrator.handle(
            trigger: trigger,
            repository: repository,
            now: now
        )
    }

    // MARK: - Handlers

    private func handleProcessingTask(_ task: BGProcessingTask) {
        scheduleProcess()
        guard repository != nil else {
            task.setTaskCompleted(success: false)
            return
        }
        let t = Task { @MainActor in
            let report = await self.handle(
                trigger: BackgroundTrigger(kind: .bgProcessingTask, source: "BGTaskScheduler")
            )
            task.setTaskCompleted(success: report?.errors.isEmpty ?? false)
        }
        task.expirationHandler = { t.cancel() }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) {
        scheduleRefresh()
        guard repository != nil else {
            task.setTaskCompleted(success: false)
            return
        }
        let t = Task { @MainActor in
            let report = await self.handle(
                trigger: BackgroundTrigger(kind: .bgAppRefreshTask, source: "BGTaskScheduler")
            )
            task.setTaskCompleted(success: report?.errors.isEmpty ?? false)
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

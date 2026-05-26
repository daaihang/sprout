import SwiftUI

struct DebugRuntimeOperationsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.backgroundOperationOrchestrator) private var backgroundOperationOrchestrator
    @Environment(\.notificationOrchestrator) private var notificationOrchestrator
    @Environment(\.remotePushSyncService) private var remotePushSyncService

    @State private var snapshot: RuntimeOperationsSnapshot?
    @State private var resultMessage: String?
    @State private var serverMetricsText: String?
    @State private var isWorking = false

    private var coordinator: RuntimeOperationsCoordinator {
        RuntimeOperationsCoordinator(
            backgroundOperationOrchestrator: backgroundOperationOrchestrator,
            notificationOrchestrator: notificationOrchestrator,
            remotePushSyncService: remotePushSyncService
        )
    }

    var body: some View {
        List {
            if let resultMessage {
                Section("Status") {
                    Text(resultMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            actionsSection
            backgroundSection
            intelligenceSection
            notificationSection
            pushSection
        }
        .navigationTitle("Runtime Operations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                Task { await reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isWorking)
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button("Run app launch recovery") {
                Task { await runBackground(.appLaunch, source: "DebugRuntimeOperationsView.appLaunch") }
            }
            Button("Run BG processing simulation") {
                Task { await runBackground(.bgProcessingTask, source: "DebugRuntimeOperationsView.bgProcessing") }
            }
            Button("Run BG refresh simulation") {
                Task { await runBackground(.bgAppRefreshTask, source: "DebugRuntimeOperationsView.bgRefresh") }
            }
            Button("Run silent push simulation") {
                Task { await runBackground(.silentPush, source: "DebugRuntimeOperationsView.silentPush") }
            }
            Button("Run debug test notification") {
                Task { await runDebugNotification() }
            }
            Button("Force APNs registration sync") {
                Task { await forcePushRegistration() }
            }
            Button("Load push server metrics") {
                Task { await loadPushServerMetrics() }
            }
            .disabled(isWorking)

            if isWorking {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var backgroundSection: some View {
        if let snapshot {
            Section("Background") {
                RuntimeValueRow(title: "Runs", value: "\(snapshot.backgroundRuns.count)")
                RuntimeValueRow(title: "Events", value: "\(snapshot.backgroundEvents.count)")
                RuntimeValueRow(title: "Pipeline statuses", value: "\(snapshot.pipelineStatuses.count)")
            }

            Section("Recent Background Runs") {
                if snapshot.backgroundRuns.isEmpty {
                    Text("No background runs.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.backgroundRuns.prefix(20)) { run in
                        RuntimeBackgroundRunRow(run: run)
                    }
                }
            }

            Section("Recent Background Events") {
                if snapshot.backgroundEvents.isEmpty {
                    Text("No background events.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.backgroundEvents.prefix(40)) { event in
                        RuntimeBackgroundEventRow(event: event)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var intelligenceSection: some View {
        if let snapshot {
            Section("Intelligence Jobs") {
                RuntimeValueRow(title: "Total jobs", value: "\(snapshot.jobQueue.totalJobCount)")
                RuntimeValueRow(title: "Due pending jobs", value: "\(snapshot.jobQueue.duePendingJobCount)")
                RuntimeValueRow(title: "Running jobs", value: "\(snapshot.jobQueue.runningJobCount)")
                RuntimeValueRow(title: "Failed jobs", value: "\(snapshot.jobQueue.failedJobCount)")
                RuntimeValueRow(title: "Cloud required jobs", value: "\(snapshot.jobQueue.cloudRequiredJobCount)")
                RuntimeValueRow(title: "Unapplied GraphDeltas", value: "\(snapshot.jobQueue.unappliedGraphDeltaCount)")
            }

            Section("Recent Jobs") {
                if snapshot.jobQueue.jobs.isEmpty {
                    Text("No jobs.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.jobQueue.jobs.prefix(20)) { job in
                        RuntimeJobRow(job: job)
                    }
                }
            }

            Section("GraphDelta Status") {
                ForEach(snapshot.jobQueue.graphDeltaCounts) { count in
                    RuntimeValueRow(title: count.label, value: "\(count.count)")
                }
                ForEach(snapshot.jobQueue.graphDeltas.prefix(8)) { delta in
                    RuntimeGraphDeltaRow(delta: delta)
                }
            }
        }
    }

    @ViewBuilder
    private var notificationSection: some View {
        if let snapshot {
            Section("Notifications Queue") {
                if snapshot.notifications.queueIntents.isEmpty {
                    Text("No queued notification intents.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.notifications.queueIntents.prefix(40)) { intent in
                        RuntimeNotificationIntentRow(intent: intent)
                    }
                }
            }

            Section("Notification History") {
                ForEach(snapshot.notifications.historyEvents.prefix(30)) { event in
                    RuntimeNotificationEventRow(event: event)
                }
                if snapshot.notifications.historyEvents.isEmpty {
                    Text("No delivered, opened, or dismissed notification events.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notification Dedupe And Errors") {
                ForEach(snapshot.notifications.dedupeEvents.prefix(20)) { event in
                    RuntimeNotificationEventRow(event: event)
                }
                ForEach(snapshot.notifications.errorEvents.prefix(20)) { event in
                    RuntimeNotificationEventRow(event: event)
                }
                if snapshot.notifications.dedupeEvents.isEmpty && snapshot.notifications.errorEvents.isEmpty {
                    Text("No dedupe hits or notification errors.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var pushSection: some View {
        if let snapshot {
            Section("Push") {
                RuntimeValueRow(title: "Owner", value: snapshot.push.ownerID ?? "none")
                RuntimeValueRow(title: "Device", value: snapshot.push.deviceID)
                RuntimeValueRow(title: "Timezone", value: snapshot.push.timezone)
                RuntimeValueRow(title: "APNs token", value: snapshot.push.hasAPNSToken ? "present" : "missing")
                RuntimeValueRow(title: "Registration digest", value: snapshot.push.hasRegistrationDigest ? "present" : "missing")
                RuntimeValueRow(title: "Pending writebacks", value: "\(snapshot.push.pendingWritebackCount)")
                RuntimeValueRow(title: "Remote intents", value: "\(snapshot.push.remoteIntentCount)")
                if let serverMetricsText {
                    Text(serverMetricsText)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    @MainActor
    private func reload() async {
        do {
            snapshot = try await coordinator.loadSnapshot(repository: memoryRepository)
            if resultMessage == nil {
                resultMessage = "Loaded runtime snapshot."
            }
        } catch {
            resultMessage = "Reload failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func runBackground(_ kind: BackgroundTriggerKind, source: String) async {
        await perform {
            await coordinator.runBackground(kind: kind, source: source, repository: memoryRepository)
        }
    }

    @MainActor
    private func runDebugNotification() async {
        await perform {
            try await coordinator.runDebugNotification(repository: memoryRepository)
        }
    }

    @MainActor
    private func forcePushRegistration() async {
        await perform {
            await coordinator.forcePushRegistration(repository: memoryRepository)
        }
    }

    @MainActor
    private func loadPushServerMetrics() async {
        await perform {
            let result = try await coordinator.loadPushServerMetrics()
            serverMetricsText = result.message
            return result
        }
    }

    @MainActor
    private func perform(_ operation: () async throws -> RuntimeOperationResult) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await operation()
            resultMessage = "\(result.label): \(result.message)"
            await reload()
        } catch {
            resultMessage = error.localizedDescription
            await reload()
        }
    }
}

private struct RuntimeValueRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
    }
}

private struct RuntimeBackgroundRunRow: View {
    let run: BackgroundOperationRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.triggerKind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(run.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(run.status == .failed ? .red : .secondary)
            }
            RuntimeValueRow(title: "ID", value: run.id.uuidString)
            RuntimeValueRow(title: "Started", value: run.startedAt.formatted(.iso8601))
            if let completedAt = run.completedAt {
                RuntimeValueRow(title: "Completed", value: completedAt.formatted(.iso8601))
            }
            if let source = run.source?.trimmedOrNil {
                RuntimeValueRow(title: "Source", value: source)
            }
            if let summary = run.summary?.trimmedOrNil {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !run.errors.isEmpty {
                Text(run.errors.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeBackgroundEventRow: View {
    let event: BackgroundOperationEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.operationKind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(event.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(event.status == .failed ? .red : .secondary)
            }
            RuntimeValueRow(title: "Run", value: String(event.runID.uuidString.prefix(8)))
            RuntimeValueRow(title: "Started", value: event.startedAt.formatted(.iso8601))
            if !event.resultCounts.isEmpty {
                Text(event.resultCounts.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let message = event.message?.trimmedOrNil {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = event.error?.trimmedOrNil {
                Text(error)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeJobRow: View {
    let job: IntelligenceJob

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(job.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(job.status == .failed ? .red : .secondary)
            }
            RuntimeValueRow(title: "ID", value: job.id.uuidString)
            RuntimeValueRow(title: "Target", value: "\(job.targetType.rawValue) · \(job.targetID.uuidString)")
            RuntimeValueRow(title: "Priority / attempts", value: "\(job.priority) / \(job.attemptCount)")
            RuntimeValueRow(title: "Cloud", value: job.requiresCloudAI ? "yes" : "no")
            RuntimeValueRow(title: "Scheduled", value: job.scheduledAt.formatted(.iso8601))
            if let lastError = job.lastError?.trimmedOrNil {
                Text(lastError)
                    .font(.caption.monospaced())
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeGraphDeltaRow: View {
    let delta: GraphDelta

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(delta.source.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(delta.appliedAt == nil ? "unapplied" : "applied")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            RuntimeValueRow(title: "ID", value: delta.id.uuidString)
            RuntimeValueRow(title: "Operations", value: delta.operations.map { "\($0.kind.rawValue):\($0.targetType.rawValue)" }.joined(separator: "\n"))
            RuntimeValueRow(title: "Requires confirmation", value: delta.requiresUserConfirmation ? "yes" : "no")
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeNotificationIntentRow: View {
    let intent: NotificationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(intent.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(intent.status.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(intent.body)
                .font(.caption)
                .foregroundStyle(.secondary)
            RuntimeValueRow(title: "Channel", value: intent.deliveryChannel.rawValue)
            RuntimeValueRow(title: "Target", value: "\(intent.targetType.rawValue) · \(intent.targetID.uuidString)")
            RuntimeValueRow(title: "Scheduled", value: intent.scheduledAt.formatted(.iso8601))
        }
        .padding(.vertical, 4)
    }
}

private struct RuntimeNotificationEventRow: View {
    let event: NotificationManagementEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.eventKind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(event.createdAt.formatted(.iso8601))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            RuntimeValueRow(title: "Intent", value: event.intentID.uuidString)
            if let message = event.message?.trimmedOrNil {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
import SwiftUI
import BackgroundTasks

struct DebugJobQueueView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    @State private var snapshot: DebugJobQueueSnapshot?
    @State private var flags: V6FeatureFlags?
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var selectedJobKind: DebugEnqueueableJobKind = .dailyQuestion
    @State private var bgTaskResult: String?

    var body: some View {
        List {
            Section("Effective gates") {
                if let flags {
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.jobWorkerGate(flags: flags))
                } else {
                    DebugCenterProgressRow(text: "Loading job worker gate")
                }
            }

            Section {
                Button("Refresh queue state") {
                    refresh()
                }
                .disabled(isWorking)

                Button("Process due jobs now") {
                    Task { await processDueJobs() }
                }
                .disabled(isWorking)

                Button("Recover unfinished jobs") {
                    Task { await recoverJobs() }
                }
                .disabled(isWorking)

                Picker("New job kind", selection: $selectedJobKind) {
                    ForEach(DebugEnqueueableJobKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                Button("Enqueue selected debug job") {
                    enqueueSelectedJob()
                }
                .disabled(isWorking)

                Button("Retry failed jobs") {
                    retryFailedJobs()
                }
                .disabled(isWorking)

                NavigationLink("Clarification Questions") {
                    DebugClarificationQuestionsView()
                }

                if isWorking {
                    DebugCenterProgressRow(text: "Working on job queue")
                }
                if let resultMessage {
                    Text(resultMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("This page uses the same repository job stores and IntelligenceJobWorker used during launch recovery and background intelligence preparation.")
            }

            Section("Background Tasks") {
                Button("Schedule BGProcessingTask") {
                    submitBGTask(identifier: BackgroundTaskIdentifier.process, isProcessing: true)
                }
                Button("Schedule BGAppRefreshTask") {
                    submitBGTask(identifier: BackgroundTaskIdentifier.refresh, isProcessing: false)
                }
                if let bgTaskResult {
                    Text(bgTaskResult)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if let snapshot {
                Section("Summary") {
                    DebugCenterValueRow(title: "Generated", value: snapshot.generatedAt.formatted(.iso8601))
                    DebugCenterValueRow(title: "Total jobs", value: "\(snapshot.totalJobCount)")
                    DebugCenterValueRow(title: "Due pending jobs", value: "\(snapshot.duePendingJobCount)")
                    DebugCenterValueRow(title: "Running jobs", value: "\(snapshot.runningJobCount)")
                    DebugCenterValueRow(title: "Failed jobs", value: "\(snapshot.failedJobCount)")
                    DebugCenterValueRow(title: "Cloud required jobs", value: "\(snapshot.cloudRequiredJobCount)")
                    DebugCenterValueRow(title: "Unapplied graph deltas", value: "\(snapshot.unappliedGraphDeltaCount)")
                }

                Section("Job status counts") {
                    ForEach(snapshot.jobStatusCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                }

                Section("Job kind counts") {
                    ForEach(snapshot.jobKindCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                }

                Section("Recent jobs") {
                    if snapshot.jobs.isEmpty {
                        Text("No jobs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.jobs.prefix(20)) { job in
                            DebugJobRow(job: job)
                        }
                    }
                }

                Section("Graph deltas") {
                    ForEach(snapshot.graphDeltaCounts) { count in
                        DebugCenterValueRow(title: count.label, value: "\(count.count)")
                    }
                    ForEach(snapshot.graphDeltas.prefix(8)) { delta in
                        VStack(alignment: .leading, spacing: 4) {
                            DebugGraphDeltaRow(delta: delta)
                            if delta.appliedAt == nil {
                                Button("Apply") {
                                    applyDelta(id: delta.id)
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                    if !snapshot.graphDeltas.filter({ $0.appliedAt == nil }).isEmpty {
                        Button("Apply all pending") {
                            applyAllPendingDeltas()
                        }
                    }
                }
            }
        }
        .navigationTitle("Job Queue")
        .toolbar {
            Button {
                if let snapshot {
                    UIPasteboard.general.string = buildReport(snapshot)
                }
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(snapshot == nil)
        }
        .task {
            refresh()
        }
    }

    @MainActor
    private func refresh() {
        do {
            let jobs = try memoryRepository.fetchIntelligenceJobs(status: nil, limit: nil)
                .sorted { $0.updatedAt > $1.updatedAt }
            let deltas = try memoryRepository.fetchGraphDeltas(applied: nil, limit: nil)
                .sorted { $0.createdAt > $1.createdAt }
            flags = try memoryRepository.fetchV6FeatureFlags()
            snapshot = DebugJobQueueSnapshot(
                generatedAt: .now,
                jobs: jobs,
                graphDeltas: deltas
            )
            resultMessage = nil
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func processDueJobs() async {
        isWorking = true
        defer { isWorking = false }
        let report = await IntelligenceJobWorker().processDueJobs(
            repository: memoryRepository,
            cloudIntelligenceService: cloudIntelligenceService,
            now: .now
        )
        resultMessage = [
            "completed=\(report.completedJobIDs.count)",
            "failed=\(report.failedJobIDs.count)",
            "unsupported=\(report.unsupportedJobIDs.count)",
            "questions=\(report.preparedQuestionCount)",
            "scheduled_notifications=\(report.scheduledNotificationCount)",
        ].joined(separator: ", ")
        refresh()
    }

    @MainActor
    private func recoverJobs() async {
        isWorking = true
        defer { isWorking = false }
        let report = await AppIntelligenceRecoveryService().recoverAfterLaunch(
            repository: memoryRepository,
            cloudIntelligenceService: cloudIntelligenceService,
            now: .now
        )
        resultMessage = [
            "resumed=\(report.resumedRunningJobIDs.count)",
            "retried=\(report.retriedFailedJobIDs.count)",
            "abandoned=\(report.abandonedFailedJobIDs.count)",
            "worker_completed=\(report.workerReport.completedJobIDs.count)",
            "errors=\(report.errors.count)",
        ].joined(separator: ", ")
        refresh()
    }

    @MainActor
    private func enqueueSelectedJob() {
        do {
            let job = IntelligenceJob(
                kind: selectedJobKind.kind,
                targetType: selectedJobKind.targetType,
                targetID: UUID(),
                status: .pending,
                priority: selectedJobKind.defaultPriority,
                scheduledAt: .now,
                requiresCloudAI: selectedJobKind.requiresCloudAI
            )
            try memoryRepository.upsertIntelligenceJob(job)
            resultMessage = "Enqueued \(job.kind.rawValue) job \(job.id.uuidString)."
            refresh()
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func retryFailedJobs() {
        do {
            let failed = try memoryRepository.fetchIntelligenceJobs(status: .failed, limit: nil)
            for job in failed {
                var retry = job
                retry.status = .pending
                retry.startedAt = nil
                retry.completedAt = nil
                retry.scheduledAt = .now
                retry.updatedAt = .now
                try memoryRepository.upsertIntelligenceJob(retry)
            }
            resultMessage = "Retried \(failed.count) failed job(s)."
            refresh()
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func applyDelta(id: UUID) {
        do {
            try memoryRepository.applyGraphDelta(id)
            resultMessage = "Applied delta \(id.uuidString.prefix(8))."
            refresh()
        } catch {
            resultMessage = "Apply failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func applyAllPendingDeltas() {
        guard let snapshot else { return }
        let pending = snapshot.graphDeltas.filter { $0.appliedAt == nil }
        var applied = 0
        var errors: [String] = []
        for delta in pending {
            do {
                try memoryRepository.applyGraphDelta(delta.id)
                applied += 1
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        resultMessage = "Applied \(applied)/\(pending.count). Errors: \(errors.isEmpty ? "none" : errors.joined(separator: ", "))"
        refresh()
    }

    private func submitBGTask(identifier: String, isProcessing: Bool) {
        do {
            if isProcessing {
                let request = BGProcessingTaskRequest(identifier: identifier)
                request.requiresNetworkConnectivity = true
                request.earliestBeginDate = nil
                try BGTaskScheduler.shared.submit(request)
            } else {
                let request = BGAppRefreshTaskRequest(identifier: identifier)
                request.earliestBeginDate = nil
                try BGTaskScheduler.shared.submit(request)
            }
            bgTaskResult = "Submitted \(identifier)"
        } catch {
            bgTaskResult = "Submit failed: \(error.localizedDescription)"
        }
    }

    private func buildReport(_ snapshot: DebugJobQueueSnapshot) -> String {
        var lines = [
            "=== Mory Job Queue Debug ===",
            "Generated: \(snapshot.generatedAt.formatted(.iso8601))",
            "Total jobs: \(snapshot.totalJobCount)",
            "Due pending: \(snapshot.duePendingJobCount)",
            "Running: \(snapshot.runningJobCount)",
            "Failed: \(snapshot.failedJobCount)",
            "Cloud required: \(snapshot.cloudRequiredJobCount)",
            "Unapplied graph deltas: \(snapshot.unappliedGraphDeltaCount)",
            "",
            "[Jobs]",
        ]
        for job in snapshot.jobs.prefix(40) {
            lines.append("\(job.kind.rawValue) \(job.status.rawValue) \(job.id.uuidString) target=\(job.targetType.rawValue)/\(job.targetID.uuidString) attempts=\(job.attemptCount) error=\(job.lastError ?? "none")")
        }
        return lines.joined(separator: "\n")
    }
}

private struct DebugJobRow: View {
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
            DebugCenterValueRow(title: "ID", value: job.id.uuidString)
            DebugCenterValueRow(title: "Target", value: "\(job.targetType.rawValue) · \(job.targetID.uuidString)")
            DebugCenterValueRow(title: "Priority / attempts", value: "\(job.priority) / \(job.attemptCount)")
            DebugCenterValueRow(title: "Cloud", value: DebugCenterFormatting.boolText(job.requiresCloudAI))
            DebugCenterValueRow(title: "Scheduled", value: job.scheduledAt.formatted(.iso8601))
            if let lastError = job.lastError?.trimmedOrNil {
                DebugCenterPayloadBlock(title: "Last error", content: lastError)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DebugGraphDeltaRow: View {
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
            DebugCenterValueRow(title: "ID", value: delta.id.uuidString)
            DebugCenterValueRow(title: "Operations", value: delta.operations.map { "\($0.kind.rawValue):\($0.targetType.rawValue)" }.joined(separator: "\n"))
            DebugCenterValueRow(title: "Confidence", value: delta.confidence.map { "\($0)" } ?? "none")
            DebugCenterValueRow(title: "Requires confirmation", value: DebugCenterFormatting.boolText(delta.requiresUserConfirmation))
        }
        .padding(.vertical, 4)
    }
}
#endif

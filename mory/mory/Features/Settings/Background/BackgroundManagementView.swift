import SwiftUI

struct BackgroundManagementView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.remotePushSyncService) private var remotePushSyncService
    @Environment(\.backgroundOperationOrchestrator) private var backgroundOperationOrchestrator

    @State private var runs: [BackgroundOperationRun] = []
    @State private var events: [BackgroundOperationEvent] = []
    @State private var jobs: [IntelligenceJob] = []
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var pushSnapshot: RemotePushDebugSnapshot?
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section("Actions") {
                Button("Run app launch recovery") {
                    Task { await run(.appLaunch, source: "debug:appLaunch") }
                }
                Button("Run BG processing simulation") {
                    Task { await run(.bgProcessingTask, source: "debug:bgProcessing") }
                }
                Button("Run BG refresh simulation") {
                    Task { await run(.bgAppRefreshTask, source: "debug:bgRefresh") }
                }
                Button("Run silent push simulation") {
                    Task { await run(.silentPush, source: "debug:silentPush") }
                }
                Button("Sync APNs registration") {
                    Task { await run(.apnsTokenUpdated, source: "debug:apnsSync") }
                }
                .disabled(isWorking)

                if isWorking {
                    ProgressView()
                }
                if let message {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section("Summary") {
                LabeledContent("Runs", value: "\(runs.count)")
                LabeledContent("Events", value: "\(events.count)")
                LabeledContent("Pending jobs", value: "\(jobs.filter { $0.status == .pending }.count)")
                LabeledContent("Failed jobs", value: "\(jobs.filter { $0.status == .failed }.count)")
                LabeledContent("Pipeline statuses", value: "\(pipelineStatuses.count)")
                if let pushSnapshot {
                    LabeledContent("APNs token", value: pushSnapshot.hasAPNSToken ? "present" : "missing")
                    LabeledContent("Push digest", value: pushSnapshot.hasRegistrationDigest ? "present" : "missing")
                    LabeledContent("Pending writebacks", value: "\(pushSnapshot.pendingWritebackCount)")
                }
            }

            Section("Recent runs") {
                if runs.isEmpty {
                    Text("No background runs.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(runs.prefix(20)) { run in
                        BackgroundRunRow(run: run)
                    }
                }
            }

            Section("Recent events") {
                if events.isEmpty {
                    Text("No background events.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events.prefix(40)) { event in
                        BackgroundEventRow(event: event)
                    }
                }
            }

            Section("Related pages") {
                NavigationLink("Notification Management") {
                    NotificationManagementView()
                }
                NavigationLink("Job Queue") {
                    DebugJobQueueView()
                }
            }
        }
        .navigationTitle("Background")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    @MainActor
    private func run(_ kind: BackgroundTriggerKind, source: String) async {
        isWorking = true
        defer { isWorking = false }
        let report = await backgroundOperationOrchestrator.handle(
            trigger: BackgroundTrigger(kind: kind, source: source),
            repository: memoryRepository,
        )
        message = "run=\(report.runID.uuidString.prefix(8)) status=\(report.status.rawValue) events=\(report.operationEvents.count) errors=\(report.errors.count)"
        await reload()
    }

    @MainActor
    private func reload() async {
        do {
            runs = try memoryRepository.fetchBackgroundOperationRuns(status: nil, limit: 50)
            events = try memoryRepository.fetchBackgroundOperationEvents(runID: nil, limit: 100)
            jobs = try memoryRepository.fetchIntelligenceJobs(status: nil, limit: nil)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 50)
            pushSnapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
            if message == nil {
                message = "Loaded \(runs.count) run(s)."
            }
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct BackgroundRunRow: View {
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
            LabeledContent("ID", value: run.id.uuidString)
            LabeledContent("Started", value: run.startedAt.formatted(.iso8601))
            if let completedAt = run.completedAt {
                LabeledContent("Completed", value: completedAt.formatted(.iso8601))
            }
            if let source = run.source?.trimmedOrNil {
                LabeledContent("Source", value: source)
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

private struct BackgroundEventRow: View {
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
            LabeledContent("Run", value: String(event.runID.uuidString.prefix(8)))
            LabeledContent("Started", value: event.startedAt.formatted(.iso8601))
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

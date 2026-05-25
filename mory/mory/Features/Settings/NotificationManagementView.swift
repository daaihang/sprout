import SwiftUI

struct NotificationManagementSnapshot: Hashable, Sendable {
    static let queueStatuses: [NotificationIntentStatus] = [
        .pending,
        .scheduled,
        .inAppOnly,
        .blocked,
    ]

    static let historyKinds: [NotificationManagementEventKind] = [
        .delivered,
        .opened,
        .dismissed,
    ]

    static let errorKinds: [NotificationManagementEventKind] = [
        .policyBlocked,
        .deliveryError,
        .routeError,
    ]

    var queueIntents: [NotificationIntent]
    var historyEvents: [NotificationManagementEvent]
    var dedupeEvents: [NotificationManagementEvent]
    var errorEvents: [NotificationManagementEvent]

    static let empty = NotificationManagementSnapshot(
        queueIntents: [],
        historyEvents: [],
        dedupeEvents: [],
        errorEvents: []
    )

    static func build(
        intents: [NotificationIntent],
        events: [NotificationManagementEvent]
    ) -> NotificationManagementSnapshot {
        NotificationManagementSnapshot(
            queueIntents: intents
                .filter { queueStatuses.contains($0.status) }
                .sorted { lhs, rhs in
                    if lhs.status != rhs.status {
                        let lhsIndex = queueStatuses.firstIndex(of: lhs.status) ?? Int.max
                        let rhsIndex = queueStatuses.firstIndex(of: rhs.status) ?? Int.max
                        return lhsIndex < rhsIndex
                    }
                    return lhs.scheduledAt < rhs.scheduledAt
                },
            historyEvents: events
                .filter { historyKinds.contains($0.eventKind) }
                .sorted { $0.createdAt > $1.createdAt },
            dedupeEvents: events
                .filter { $0.eventKind == .deduped }
                .sorted { $0.createdAt > $1.createdAt },
            errorEvents: events
                .filter { errorKinds.contains($0.eventKind) }
                .sorted { $0.createdAt > $1.createdAt }
        )
    }
}

struct NotificationManagementView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.notificationOrchestrator) private var notificationOrchestrator
    @Environment(\.remotePushSyncService) private var remotePushSyncService

    @State private var intents: [NotificationIntent] = []
    @State private var events: [NotificationManagementEvent] = []
    @State private var remoteSnapshot: RemotePushDebugSnapshot?
    @State private var serverMetricsText: String?
    @State private var resultMessage: String?
    @State private var isWorking = false

    private var snapshot: NotificationManagementSnapshot {
        NotificationManagementSnapshot.build(intents: intents, events: events)
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

            queueSection
            historySection
            dedupeSection
            errorsSection

            Section("Preferences") {
                Text("Notification preferences are kept here so Settings and Debug use the same controls.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            NotificationPreferencesContent(memoryRepository: memoryRepository)
        }
        .navigationTitle("Notification Management")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isWorking)

                Menu {
                    Button("Run background trigger") {
                        Task { await runBackgroundTrigger() }
                    }
                    Button("Run debug test notification") {
                        Task { await runDebugTestNotification() }
                    }
                    Button("Force APNs registration sync") {
                        Task { await syncRemoteRegistration() }
                    }
                    Button("Load push server metrics") {
                        Task { await loadServerMetrics() }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .disabled(isWorking)
            }
        }
        .task {
            await reload()
        }
        .refreshable {
            await reload()
        }
    }

    private var queueSection: some View {
        Section {
            if snapshot.queueIntents.isEmpty {
                Text("No pending, scheduled, in-app-only, or blocked notification intents.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(NotificationManagementSnapshot.queueStatuses.filter { status in
                    snapshot.queueIntents.contains { $0.status == status }
                }) { status in
                    let items = snapshot.queueIntents.filter { $0.status == status }
                    DisclosureGroup("\(status.rawValue) (\(items.count))") {
                        ForEach(items) { intent in
                            NotificationManagementIntentRow(intent: intent)
                        }
                    }
                }
            }
        } header: {
            Text("Queue")
        } footer: {
            if let remoteSnapshot {
                Text(remoteSummary(remoteSnapshot))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            if snapshot.historyEvents.isEmpty {
                Text("No delivered, opened, or dismissed notification events.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.historyEvents) { event in
                    NotificationManagementEventRow(event: event)
                }
            }
        }
    }

    private var dedupeSection: some View {
        Section("Dedupe") {
            if snapshot.dedupeEvents.isEmpty {
                Text("No dedupe hits.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.dedupeEvents) { event in
                    NotificationManagementEventRow(event: event)
                }
            }
        }
    }

    private var errorsSection: some View {
        Section("Errors") {
            if snapshot.errorEvents.isEmpty {
                Text("No policy, delivery, or route errors.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.errorEvents) { event in
                    NotificationManagementEventRow(event: event)
                }
            }

            if let serverMetricsText {
                Text(serverMetricsText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    @MainActor
    private func reload() async {
        do {
            intents = try memoryRepository.fetchNotificationIntents(status: nil, limit: 160)
            events = try memoryRepository.fetchNotificationManagementEvents(kind: nil, limit: 240)
            remoteSnapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
            resultMessage = "Loaded \(intents.count) intent(s) and \(events.count) management event(s)."
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func runBackgroundTrigger() async {
        await perform("Background trigger") {
            let report = try await notificationOrchestrator.orchestrate(
                trigger: .backgroundRefresh,
                repository: memoryRepository
            )
            return reportSummary(report)
        }
    }

    @MainActor
    private func runDebugTestNotification() async {
        await perform("Debug test") {
            let intent = NotificationIntent(
                kind: .debugTest,
                title: "Mory",
                body: "Debug notification test.",
                privacyLevel: .generic,
                targetType: .record,
                targetID: UUID(),
                scheduledAt: .now.addingTimeInterval(3),
                deliveryChannel: .local,
                deepLink: "mory://home",
                reason: "Manual debug notification test.",
                sourceTrigger: .debugManual,
                createdBy: .debug
            )
            let report = try await notificationOrchestrator.orchestrate(
                trigger: .debugManual(intent: intent),
                repository: memoryRepository
            )
            return reportSummary(report)
        }
    }

    @MainActor
    private func syncRemoteRegistration() async {
        await perform("APNs sync") {
            remotePushSyncService.registerSystemRemoteNotificationsIfNeeded(repository: memoryRepository)
            await remotePushSyncService.syncRegistrationIfPossible(
                repository: memoryRepository,
                force: true
            )
            return "Requested APNs registration sync."
        }
    }

    @MainActor
    private func loadServerMetrics() async {
        await perform("Server metrics") {
            serverMetricsText = try await remotePushSyncService.fetchServerMetricsText()
            return "Loaded push server metrics."
        }
    }

    @MainActor
    private func perform(_ label: String, operation: () async throws -> String) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            resultMessage = "\(label): \(try await operation())"
            await reload()
        } catch {
            resultMessage = "\(label) failed: \(error.localizedDescription)"
            await reload()
        }
    }

    private func reportSummary(_ report: NotificationOrchestrationReport) -> String {
        [
            "generated=\(report.generatedIntentIDs.count)",
            "deduped=\(report.dedupedIntentIDs.count)",
            "blocked=\(report.blockedIntentIDs.count)",
            "scheduled=\(report.scheduledIntentIDs.count)",
            "remote=\(report.remoteEnqueuedIntentIDs.count)",
            "inAppOnly=\(report.inAppOnlyIntentIDs.count)",
            "errors=\(report.errors.count)",
        ].joined(separator: ", ")
    }

    private func remoteSummary(_ snapshot: RemotePushDebugSnapshot) -> String {
        [
            "owner=\(snapshot.ownerID ?? "none")",
            "device=\(snapshot.deviceID)",
            "token=\(snapshot.hasAPNSToken ? "yes" : "no")",
            "pendingWritebacks=\(snapshot.pendingWritebackCount)",
            "remoteIntents=\(snapshot.remoteIntentCount)",
        ].joined(separator: " · ")
    }
}

private struct NotificationManagementIntentRow: View {
    let intent: NotificationIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(intent.kind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(intent.deliveryChannel.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(intent.body)
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledContent("Target", value: "\(intent.targetType.rawValue) · \(intent.targetID.uuidString)")
                .font(.caption)
            LabeledContent("Reason", value: intent.reason.ifEmpty("none"))
                .font(.caption)
            LabeledContent("Trigger", value: intent.sourceTrigger.rawValue)
                .font(.caption)
            if let deepLink = intent.deepLink?.trimmedOrNil {
                Text(deepLink)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !intent.blockedReasons.isEmpty {
                Text("Blocked: \(intent.blockedReasons.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NotificationManagementEventRow: View {
    let event: NotificationManagementEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(event.eventKind.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(event.message)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let dedupeKey = event.dedupeKey?.trimmedOrNil {
                Text("dedupeKey=\(dedupeKey)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text(eventMeta)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }

    private var eventMeta: String {
        [
            event.trigger.map { "trigger=\($0.rawValue)" },
            event.kind.map { "kind=\($0.rawValue)" },
            event.targetType.map { "target=\($0.rawValue)/\(event.targetID?.uuidString ?? "none")" },
            event.intentID.map { "intent=\($0.uuidString)" },
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        .ifEmpty("no metadata")
    }
}

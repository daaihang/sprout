#if DEBUG
import SwiftUI

struct DebugRemotePushDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.remotePushSyncService) private var remotePushSyncService
    @Environment(\.notificationOrchestrator) private var notificationOrchestrator

    @State private var snapshot: RemotePushDebugSnapshot?
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var serverMetricsText: String?

    var body: some View {
        List {
            Section {
                if let snapshot {
                    LabeledContent("Local owner", value: snapshot.ownerID ?? "none")
                    LabeledContent("Device ID", value: snapshot.deviceID)
                    LabeledContent("Timezone", value: snapshot.timezone)
                    LabeledContent("APNs token", value: snapshot.apnsTokenPreview ?? (snapshot.hasAPNSToken ? "present" : "missing"))
                    LabeledContent("Registration digest", value: snapshot.hasRegistrationDigest ? "present" : "missing")
                    LabeledContent("Pending writebacks", value: "\(snapshot.pendingWritebackCount)")
                    LabeledContent("Pending intents", value: "\(snapshot.pendingIntentCount)")
                    LabeledContent("Scheduled intents", value: "\(snapshot.scheduledIntentCount)")
                    LabeledContent("Remote intents", value: "\(snapshot.remoteIntentCount)")
                } else {
                    Text("Remote push diagnostics have not been loaded.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("State")
            } footer: {
                Text("Internal-only diagnostics for APNs token sync, delivery writeback retry, and server-side queued push delivery.")
            }

            Section {
                Button("Refresh remote push state") {
                    Task { await refresh() }
                }
                .disabled(isWorking)

                Button("Force APNs registration sync") {
                    Task { await forceSync() }
                }
                .disabled(isWorking)

                Button("Route next notification candidate") {
                    Task { await routeNextNotificationCandidate() }
                }
                .disabled(isWorking)

                Button("Enqueue test push") {
                    Task { await enqueueTestPush() }
                }
                .disabled(isWorking)

                Button("Load server worker metrics") {
                    Task { await loadServerMetrics() }
                }
                .disabled(isWorking)

                if let resultMessage {
                    Text(resultMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Actions")
            }

            if let serverMetricsText {
                Section {
                    DebugRemotePushMetricRows(metricsText: serverMetricsText)
                    DisclosureGroup("Raw metrics") {
                        Text(serverMetricsText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Server worker metrics")
                } footer: {
                    Text("Use APNs environment/topic, sent/failed/retried/permanent counters, and last_error to verify real-device push delivery.")
                }
            }
        }
        .navigationTitle("Remote Push")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isWorking)
            }
        }
        .task {
            await refresh()
        }
    }

    private func refresh() async {
        isWorking = true
        defer { isWorking = false }
        snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
    }

    private func forceSync() async {
        isWorking = true
        resultMessage = nil
        await remotePushSyncService.syncRegistrationIfPossible(repository: memoryRepository, force: true)
        snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
        resultMessage = "Registration sync attempted."
        isWorking = false
    }

    private func routeNextNotificationCandidate() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }

        do {
            let report = try await notificationOrchestrator.orchestrate(
                trigger: .backgroundRefresh,
                repository: memoryRepository
            )
            resultMessage = "generated \(report.generatedIntentIDs.count), scheduled \(report.scheduledIntentIDs.count), remote \(report.remoteEnqueuedIntentIDs.count), blocked \(report.blockedIntentIDs.count)"
            snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func enqueueTestPush() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }

        do {
            let timestamp = Date.now.formatted(date: .omitted, time: .standard)
            let targetID = UUID()
            let intent = NotificationIntent(
                kind: .debugTest,
                title: "Mory Debug",
                body: "Remote push test from Debug at \(timestamp).",
                privacyLevel: .generic,
                targetType: .record,
                targetID: targetID,
                scheduledAt: .now,
                status: .pending,
                deliveryChannel: .remote,
                deepLink: "mory://home",
                reason: "Debug manual push.",
                sourceTrigger: .debugManual,
                createdBy: .debug
            )
            let report = try await notificationOrchestrator.orchestrate(
                trigger: .debugManual(intent: intent),
                repository: memoryRepository
            )
            resultMessage = "Test generated \(report.generatedIntentIDs.count), scheduled \(report.scheduledIntentIDs.count), remote \(report.remoteEnqueuedIntentIDs.count), blocked \(report.blockedIntentIDs.count)."
            snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
        } catch {
            resultMessage = error.localizedDescription
        }
    }

    private func loadServerMetrics() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }

        do {
            serverMetricsText = try await remotePushSyncService.fetchServerMetricsText()
            resultMessage = "Server metrics loaded."
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}

private struct DebugRemotePushMetricRows: View {
    let metricsText: String

    var body: some View {
        let metrics = parsedMetrics
        Group {
            LabeledContent("APNs", value: metrics["apns_environment_info"] ?? "missing")
            LabeledContent("Worker", value: metrics["push_delivery_worker_enabled_info"] ?? "missing")
            LabeledContent("Sent", value: metrics["push_delivery_sent_total"] ?? "0")
            LabeledContent("Failed", value: metrics["push_delivery_failed_total"] ?? "0")
            LabeledContent("Retried", value: metrics["push_delivery_retried_total"] ?? "0")
            LabeledContent("Permanent failed", value: metrics["push_delivery_permanent_failed_total"] ?? "0")
            if let lastError = metrics["push_delivery_last_error_info"] {
                LabeledContent("Last error", value: lastError)
            }
        }
    }

    private var parsedMetrics: [String: String] {
        var output: [String: String] = [:]
        for rawLine in metricsText.split(separator: "\n") {
            let line = String(rawLine)
            guard let firstSpace = line.firstIndex(of: " ") else { continue }
            let key = String(line[..<firstSpace])
            let value = String(line[line.index(after: firstSpace)...])
            let normalizedKey = key.split(separator: "{").first.map(String.init) ?? key
            if output[normalizedKey] == nil {
                output[normalizedKey] = key.contains("{") ? "\(key) \(value)" : value
            }
        }
        return output
    }
}
#endif

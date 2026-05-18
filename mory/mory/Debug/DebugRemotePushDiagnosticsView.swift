import SwiftUI

struct DebugRemotePushDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.remotePushSyncService) private var remotePushSyncService

    @State private var snapshot: RemotePushDebugSnapshot?
    @State private var isWorking = false
    @State private var resultMessage: String?

    var body: some View {
        List {
            Section {
                if let snapshot {
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

                Button("Enqueue first pending intent") {
                    Task { await enqueueFirstPendingIntent() }
                }
                .disabled(isWorking)

                Button("Enqueue test push") {
                    Task { await enqueueTestPush() }
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

    private func enqueueFirstPendingIntent() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }

        do {
            guard let intent = try memoryRepository.fetchNotificationIntents(status: .pending, limit: 1).first else {
                resultMessage = "No pending notification intent."
                snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
                return
            }
            let response = try await remotePushSyncService.enqueueRemoteNotificationIntent(intent)
            resultMessage = "Queued \(response.queuedCount), sent \(response.sentCount), failed \(response.failedCount), retried \(response.retriedCount ?? 0), permanent \(response.permanentFailedCount ?? 0)."
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
            let intent = NotificationIntent(
                kind: .dailyQuestion,
                title: "Mory Debug",
                body: "Remote push test from Debug.",
                privacyLevel: .generic,
                targetType: .question,
                targetID: UUID(),
                scheduledAt: .now,
                status: .pending,
                deliveryChannel: .remote
            )
            try memoryRepository.upsertNotificationIntent(intent)
            let response = try await remotePushSyncService.enqueueRemoteNotificationIntent(intent)
            resultMessage = "Test queued \(response.queuedCount), sent \(response.sentCount), failed \(response.failedCount), retried \(response.retriedCount ?? 0), permanent \(response.permanentFailedCount ?? 0)."
            snapshot = await remotePushSyncService.fetchDebugSnapshot(repository: memoryRepository)
        } catch {
            resultMessage = error.localizedDescription
        }
    }
}

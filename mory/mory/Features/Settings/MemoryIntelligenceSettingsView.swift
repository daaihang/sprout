import SwiftUI

struct MemoryIntelligenceSettingsView: View {
    private let journalingService = JournalingSuggestionContextService()

    var body: some View {
        List {
            Section("Review") {
                NavigationLink {
                    GraphDeltaReviewView()
                } label: {
                    Label("GraphDelta Review", systemImage: "point.3.connected.trianglepath.dotted")
                }

                NavigationLink {
                    AffectHistoryView()
                } label: {
                    Label("Affect History", systemImage: "waveform.path.ecg")
                }

                NavigationLink {
                    NotificationHistoryView()
                } label: {
                    Label("Notification History", systemImage: "bell.badge")
                }

                NavigationLink {
                    PlatformCaptureDiagnosticsView()
                } label: {
                    Label("Platform Capture Diagnostics", systemImage: "checklist.checked")
                }
            }

            Section("Journaling Suggestions") {
                let availability = journalingService.availability()
                LabeledContent("Available", value: availability.isAvailable ? "Yes" : "No")
                LabeledContent("Reason", value: availability.reason.rawValue)
                Text(availability.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Memory Intelligence")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NotificationHistoryView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var intents: [NotificationIntent] = []
    @State private var message: String?

    var body: some View {
        List {
            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notification Intents") {
                if intents.isEmpty {
                    Text("No notification history.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(intents) { intent in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intent.kind.rawValue)
                                .font(.subheadline.weight(.semibold))
                            Text(intent.body)
                                .font(.subheadline)
                            Text(metaSummary(intent))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let deepLink = intent.deepLink?.trimmedOrNil {
                                Text(deepLink)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            if !intent.blockedReasons.isEmpty {
                                Text("Blocked: \(intent.blockedReasons.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Notification History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reload()
        }
        .refreshable {
            reload()
        }
    }

    @MainActor
    private func reload() {
        do {
            intents = try memoryRepository.fetchNotificationIntents(status: nil, limit: 80)
            message = "Loaded \(intents.count) notification intent(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func metaSummary(_ intent: NotificationIntent) -> String {
        [
            "status=\(intent.status.rawValue)",
            "trigger=\(intent.sourceTrigger.rawValue)",
            "channel=\(intent.deliveryChannel.rawValue)",
            "reason=\(intent.reason.ifEmpty("none"))",
        ].joined(separator: " · ")
    }
}

private struct AffectHistoryView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var snapshots: [AffectSnapshot] = []
    @State private var message: String?

    var body: some View {
        List {
            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Affect Snapshots") {
                if snapshots.isEmpty {
                    Text("No affect snapshots.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshots) { snapshot in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.primaryMoodText)
                                .font(.subheadline.weight(.semibold))
                            Text(vectorSummary(snapshot))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !snapshot.toneHints.isEmpty {
                                Text("Tone: \(snapshot.toneHints.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !snapshot.sources.isEmpty {
                                Text("Source: \(snapshot.sources.map(\.rawValue).joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Affect History")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            reload()
        }
        .refreshable {
            reload()
        }
    }

    @MainActor
    private func reload() {
        do {
            snapshots = try memoryRepository.fetchAffectSnapshots(recordID: nil, limit: 80)
            message = "Loaded \(snapshots.count) snapshot(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    private func vectorSummary(_ snapshot: AffectSnapshot) -> String {
        [
            snapshot.valence.map { String(format: "v=%.2f", $0) },
            snapshot.arousal.map { String(format: "a=%.2f", $0) },
            snapshot.dominance.map { String(format: "d=%.2f", $0) },
            snapshot.intensity.map { String(format: "i=%.2f", $0) },
        ]
        .compactMap { $0 }
        .joined(separator: " ")
    }
}

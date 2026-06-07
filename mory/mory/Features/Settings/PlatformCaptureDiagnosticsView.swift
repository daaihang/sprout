import SwiftUI

struct PlatformCaptureDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var snapshot: PlatformCaptureDiagnosticsSnapshot?
    @State private var message: String?

    private let diagnosticsService = PlatformCaptureDiagnosticsService()

    var body: some View {
        List {
            if let message {
                Section("Status") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot {
                Section("Summary") {
                    LabeledContent("Generated", value: snapshot.generatedAt.formatted(date: .abbreviated, time: .standard))
                    LabeledContent("Ready", value: "\(snapshot.summary.ready)")
                    LabeledContent("Warning", value: "\(snapshot.summary.warning)")
                    LabeledContent("Blocked", value: "\(snapshot.summary.blocked)")
                    LabeledContent("Manual checks", value: "\(snapshot.summary.manual)")
                }

                Section("External Capture Handoff") {
                    LabeledContent("Pending", value: "\(snapshot.inboxCounts.pending)")
                    LabeledContent("Imported", value: "\(snapshot.inboxCounts.imported)")
                    LabeledContent("Dismissed", value: "\(snapshot.inboxCounts.dismissed)")
                    LabeledContent("With errors", value: "\(snapshot.inboxCounts.failed)")

                    DebugActionNotice(
                        .mutating,
                        message: "Seeding writes a real external capture inbox item for validation."
                    )

                    Button {
                        seedShareStyleTestItem()
                    } label: {
                        Label("Seed Share-style Test Item", systemImage: "plus.square.on.square")
                    }
                }

                Section("Capability Checks") {
                    ForEach(snapshot.capabilityItems) { item in
                        DiagnosticItemRow(item: item)
                    }
                }

                Section("Manual Device Checklist") {
                    ForEach(snapshot.manualValidationItems) { item in
                        DiagnosticItemRow(item: item)
                    }
                }
            } else {
                Section {
                    Button {
                        reload()
                    } label: {
                        Label("Load Diagnostics", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .navigationTitle("Platform Capture")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reload platform capture diagnostics")
            }
        }
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
            let inboxItems = try memoryRepository.fetchExternalCaptureInbox(status: nil, limit: nil)
            snapshot = diagnosticsService.makeSnapshot(inboxItems: inboxItems)
            message = "Loaded \(inboxItems.count) external capture item(s)."
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func seedShareStyleTestItem() {
        do {
            _ = try memoryRepository.enqueueExternalCapture(
                ExternalCaptureRequest(
                    sourceKind: .shareSheet,
                    title: "Share validation sample",
                    text: "This is a platform capture validation item.",
                    url: "https://example.com/mory-share-validation",
                    context: "platformCaptureDiagnostics:manualSeed"
                ),
                receivedAt: .now
            )
            reload()
        } catch {
            message = error.localizedDescription
        }
    }
}

private struct DiagnosticItemRow: View {
    let item: PlatformCaptureDiagnosticItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(item.title, systemImage: iconName)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(item.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Text(item.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !item.evidence.isEmpty {
                Text(item.evidence.joined(separator: " | "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch item.status {
        case .ready:
            "checkmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .blocked:
            "xmark.octagon"
        case .manual:
            "checklist"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .ready:
            .green
        case .warning:
            .orange
        case .blocked:
            .red
        case .manual:
            .blue
        }
    }
}

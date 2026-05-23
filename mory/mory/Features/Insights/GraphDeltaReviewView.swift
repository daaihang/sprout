import SwiftUI

struct GraphDeltaReviewView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var pending: [GraphDelta] = []
    @State private var applied: [GraphDelta] = []
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

            Section("Pending Proposals") {
                if pending.isEmpty {
                    Text("No pending graph deltas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pending) { delta in
                        VStack(alignment: .leading, spacing: 8) {
                            GraphDeltaRow(delta: delta)
                            HStack {
                                Button("Apply") {
                                    apply(delta.id)
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Leave pending") {
                                    message = "Left \(delta.id.uuidString.prefix(8)) pending."
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Applied") {
                if applied.isEmpty {
                    Text("No applied graph deltas yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(applied) { delta in
                        GraphDeltaRow(delta: delta)
                    }
                }
            }
        }
        .navigationTitle("GraphDelta Review")
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
            let deltas = try memoryRepository.fetchGraphDeltas(applied: nil, limit: 200)
                .sorted(by: { $0.createdAt > $1.createdAt })
            pending = deltas.filter { $0.appliedAt == nil }
            applied = deltas.filter { $0.appliedAt != nil }
            if message == nil {
                message = "Loaded \(deltas.count) graph delta(s)."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func apply(_ id: UUID) {
        do {
            try memoryRepository.applyGraphDelta(id)
            message = "Applied \(id.uuidString.prefix(8))."
            reload()
        } catch {
            message = "Apply failed: \(error.localizedDescription)"
        }
    }
}

private struct GraphDeltaRow: View {
    let delta: GraphDelta

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(delta.source.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(delta.appliedAt == nil ? "pending" : "applied")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Confidence: \(delta.confidence.map { String(format: "%.2f", $0) } ?? "none")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Requires confirmation: \(delta.requiresUserConfirmation ? "yes" : "no")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(delta.operations.map(operationSummary).joined(separator: "\n"))
                .font(.caption)
                .textSelection(.enabled)
        }
    }

    private func operationSummary(_ op: GraphDeltaOperation) -> String {
        var parts: [String] = [
            op.kind.rawValue,
            "\(op.targetType.rawValue):\(op.targetID.uuidString.prefix(8))",
        ]
        if let relatedID = op.relatedID {
            parts.append("related:\(relatedID.uuidString.prefix(8))")
        }
        if let stringValue = op.stringValue?.trimmedOrNil {
            parts.append("value:\(stringValue)")
        }
        return parts.joined(separator: " · ")
    }
}

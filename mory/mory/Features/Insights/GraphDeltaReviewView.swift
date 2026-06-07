import SwiftUI

struct GraphDeltaReviewView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var pending: [GraphDelta] = []
    @State private var applied: [GraphDelta] = []
    @State private var rejected: [(delta: GraphDelta, event: CorrectionEvent)] = []
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
                DebugActionNotice(
                    .mutating,
                    message: "Apply and reject update local graph proposal and correction state."
                )
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

                                Button("Reject") {
                                    reject(delta.id)
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

            Section("Rejected") {
                DebugActionNotice(
                    .mutating,
                    message: "Undo reject writes a reversal correction event."
                )
                if rejected.isEmpty {
                    Text("No rejected graph deltas.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(rejected, id: \.event.id) { pair in
                        VStack(alignment: .leading, spacing: 8) {
                            GraphDeltaRow(delta: pair.delta, statusOverride: "rejected")
                            if let note = pair.event.note {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Undo reject") {
                                undoReject(pair.event.id)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
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
            let rejectionEvents = try memoryRepository.fetchCorrectionEvents(kind: .graphDeltaRejected, limit: 500)
                .filter { $0.reversedAt == nil }
            let rejectedByDeltaID = Dictionary(
                rejectionEvents.compactMap { event -> (UUID, CorrectionEvent)? in
                    guard let value = event.metadata["graphDeltaID"],
                          let id = UUID(uuidString: value) else { return nil }
                    return (id, event)
                },
                uniquingKeysWith: { first, _ in first }
            )
            pending = deltas.filter { $0.appliedAt == nil && rejectedByDeltaID[$0.id] == nil }
            applied = deltas.filter { $0.appliedAt != nil }
            rejected = deltas.compactMap { delta in
                guard let event = rejectedByDeltaID[delta.id] else { return nil }
                return (delta, event)
            }
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

    @MainActor
    private func reject(_ id: UUID) {
        do {
            try memoryRepository.rejectGraphDelta(id, note: "User rejected this GraphDelta proposal from review.")
            message = "Rejected \(id.uuidString.prefix(8))."
            reload()
        } catch {
            message = "Reject failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func undoReject(_ eventID: UUID) {
        do {
            try memoryRepository.reverseCorrectionEvent(eventID, reversedAt: .now)
            message = "Undo reject recorded."
            reload()
        } catch {
            message = "Undo reject failed: \(error.localizedDescription)"
        }
    }
}

private struct GraphDeltaRow: View {
    let delta: GraphDelta
    var statusOverride: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(delta.source.rawValue)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(statusOverride ?? (delta.appliedAt == nil ? "pending" : "applied"))
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

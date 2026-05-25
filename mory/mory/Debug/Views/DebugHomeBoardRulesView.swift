#if DEBUG
import SwiftUI
import SwiftData

struct DebugHomeBoardRulesView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var snapshot: HomeBoardDebugSnapshot?
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var copiedToast: String?

    var body: some View {
        List {
            Section {
                Button {
                    refresh()
                } label: {
                    Label(isRefreshing ? "Refreshing" : "Refresh rule snapshot", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)

                if let snapshot {
                    Button {
                        UIPasteboard.general.string = buildReport(snapshot)
                        showCopiedToast("Home Board report copied")
                    } label: {
                        Label("Copy rule report", systemImage: "doc.on.doc")
                    }
                }

                if isRefreshing {
                    DebugProgressRow(text: "Loading Home Board rules")
                }
                if let copiedToast {
                    Text(copiedToast)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("This page calls the same repository and HomeBoardRuleEngine used by Today, then exposes the rule inputs, local preferences, and final visible cards.")
            }

            if let snapshot {
                Section("Rule inputs") {
                    DebugValueRow(title: "Generated", value: snapshot.generatedAt.formatted(.iso8601))
                    DebugValueRow(title: "Limit", value: "\(snapshot.limit)")
                    DebugValueRow(title: "Memories", value: "\(snapshot.input.memoryCount)")
                    DebugValueRow(title: "Today memories", value: "\(snapshot.input.todayMemoryCount)")
                    DebugValueRow(title: "Recent 24h memories", value: "\(snapshot.input.recent24HourMemoryCount)")
                    DebugValueRow(title: "Context memories", value: "\(snapshot.input.contextMemoryCount)")
                    DebugValueRow(title: "High salience memories", value: "\(snapshot.input.highSalienceMemoryCount)")
                    DebugValueRow(title: "Graph links/entities/edges", value: "\(snapshot.input.graphLinkCount) / \(snapshot.input.entityCount) / \(snapshot.input.edgeCount)")
                    DebugValueRow(title: "Accepted arcs", value: "\(snapshot.input.acceptedArcCount)")
                    DebugValueRow(title: "Active accepted arcs", value: "\(snapshot.input.activeAcceptedArcCount)")
                    DebugValueRow(title: "Suggested reflections", value: "\(snapshot.input.suggestedReflectionCount)")
                    DebugValueRow(title: "Saved reflections", value: "\(snapshot.input.savedReflectionCount)")
                    DebugValueRow(title: "Running / failed pipeline", value: "\(snapshot.input.runningPipelineCount) / \(snapshot.input.failedPipelineCount)")
                }

                Section("Local preferences") {
                    DebugValueRow(title: "Total", value: "\(snapshot.preferences.totalCount)")
                    DebugValueRow(title: "Pinned", value: "\(snapshot.preferences.pinnedCount)")
                    DebugValueRow(title: "Hidden", value: "\(snapshot.preferences.hiddenCount)")
                    DebugValueRow(title: "Dismissed", value: "\(snapshot.preferences.dismissedCount)")
                }

                Section("Visible cards") {
                    if snapshot.board.items.isEmpty {
                        Text("No visible cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.board.items) { item in
                            DebugHomeBoardRuleItemRow(item: item)
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("Home Board Rules")
        .task {
            if snapshot == nil {
                refresh()
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        errorMessage = nil
        do {
            snapshot = try memoryRepository.fetchHomeBoardDebugSnapshot(for: .now, limit: 12)
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func showCopiedToast(_ message: String) {
        copiedToast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copiedToast = nil
        }
    }

    private func buildReport(_ snapshot: HomeBoardDebugSnapshot) -> String {
        var lines: [String] = []
        lines.append("=== Mory Home Board Rule Report ===")
        lines.append("Generated: \(snapshot.generatedAt.formatted(.iso8601))")
        lines.append("Date: \(snapshot.date.formatted(.iso8601))")
        lines.append("Limit: \(snapshot.limit)")
        lines.append("")
        lines.append("[Inputs]")
        lines.append("Memories: \(snapshot.input.memoryCount)")
        lines.append("Today memories: \(snapshot.input.todayMemoryCount)")
        lines.append("Recent 24h memories: \(snapshot.input.recent24HourMemoryCount)")
        lines.append("Context memories: \(snapshot.input.contextMemoryCount)")
        lines.append("High salience memories: \(snapshot.input.highSalienceMemoryCount)")
        lines.append("Graph links/entities/edges: \(snapshot.input.graphLinkCount)/\(snapshot.input.entityCount)/\(snapshot.input.edgeCount)")
        lines.append("Accepted arcs: \(snapshot.input.acceptedArcCount)")
        lines.append("Active accepted arcs: \(snapshot.input.activeAcceptedArcCount)")
        lines.append("Suggested reflections: \(snapshot.input.suggestedReflectionCount)")
        lines.append("Saved reflections: \(snapshot.input.savedReflectionCount)")
        lines.append("Running/failed pipeline: \(snapshot.input.runningPipelineCount)/\(snapshot.input.failedPipelineCount)")
        lines.append("")
        lines.append("[Preferences]")
        lines.append("Total: \(snapshot.preferences.totalCount)")
        lines.append("Pinned: \(snapshot.preferences.pinnedCount)")
        lines.append("Hidden: \(snapshot.preferences.hiddenCount)")
        lines.append("Dismissed: \(snapshot.preferences.dismissedCount)")
        lines.append("")
        lines.append("[Visible Cards]")
        for (index, item) in snapshot.board.items.enumerated() {
            lines.append("\(index + 1). \(item.cardKind.rawValue) \(renderTitle(for: item))")
            lines.append("   key: \(item.compositionItem.itemKey)")
            lines.append("   target: \(item.compositionItem.targetType.rawValue) \(item.compositionItem.targetID.uuidString)")
            lines.append("   priority: \(item.priority)")
            lines.append("   reason: \(item.reason)")
            lines.append("   pinned/hidden/dismissed: \(item.isPinned)/\(item.isHidden)/\(item.dismissedAt?.formatted(.iso8601) ?? "nil")")
            lines.append("   sourceRecordIDs: \(item.sourceRecordIDs.map(\.uuidString).joined(separator: ", "))")
            lines.append("   updatedAt: \(item.updatedAt.formatted(.iso8601))")
        }
        return lines.joined(separator: "\n")
    }
}

struct DebugHomeBoardRuleItemRow: View {
    let item: HomeBoardItemSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.cardKind.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Text("priority \(item.priority.formatted(.number.precision(.fractionLength(1))))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(renderTitle(for: item))
                .font(.subheadline.weight(.semibold))

            Text(item.reason)
                .font(.caption)
                .foregroundStyle(.secondary)

            DebugValueRow(title: "Card key", value: item.compositionItem.itemKey)
            DebugValueRow(title: "Target", value: "\(item.compositionItem.targetType.rawValue) · \(item.compositionItem.targetID.uuidString)")
            DebugValueRow(title: "Layout", value: "\(item.layout.layer.rawValue) · \(item.layout.span.widthColumns)x\(item.layout.span.heightUnits)")
            DebugValueRow(title: "Sources", value: item.sourceRecordIDs.isEmpty ? "none" : item.sourceRecordIDs.prefix(4).map(\.uuidString).joined(separator: "\n"))
            DebugValueRow(title: "Flags", value: "pinned=\(item.isPinned) hidden=\(item.isHidden) dismissed=\(item.dismissedAt?.formatted(.iso8601) ?? "nil")")
            DebugValueRow(title: "Updated", value: item.updatedAt.formatted(.iso8601))
        }
        .padding(.vertical, 4)
    }
}

private func renderTitle(for item: HomeBoardItemSnapshot) -> String {
    switch item.renderValue {
    case let .memory(memory):
        return memory.title
    case let .arc(arc):
        return arc.title
    case let .reflection(reflection):
        return reflection.title
    case let .systemPrompt(title, _, _):
        return title
    case let .contextCluster(title, _, _):
        return title
    case let .pendingAction(title, _, _):
        return title
    case let .clarificationQuestion(question, profile):
        if let profile {
            return "\(profile.displayName): \(question.prompt)"
        }
        return question.prompt
    case let .yesterdayPanel(title, _, _):
        return title
    }
}
#endif

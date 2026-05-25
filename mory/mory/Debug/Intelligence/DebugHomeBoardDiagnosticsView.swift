import SwiftUI

struct DebugHomeBoardDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var snapshot: HomeBoardDebugSnapshot?
    @State private var preferences: IntelligencePreferences?
    @State private var flags: V6FeatureFlags?
    @State private var limit = 12
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        List {
            Section("Effective gates") {
                if let preferences, let flags {
                    DebugV6GateDiagnosticRow(diagnostic: V6DebugControls.homeBoardGate(preferences: preferences, flags: flags))
                    DebugCenterValueRow(title: "Home suggestions", value: preferences.homeSuggestionsEnabled ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Home grid", value: flags.homeGrid ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Entity profiles", value: flags.entityProfiles ? "enabled" : "disabled")
                    DebugCenterValueRow(title: "Clarification questions", value: flags.clarificationQuestions ? "enabled" : "disabled")
                } else {
                    DebugCenterProgressRow(text: "Loading Home Board gates")
                }
            }

            Section {
                Stepper("Limit: \(limit)", value: $limit, in: 4...24)
                Button("Refresh Home Board debug snapshot") {
                    refresh()
                }
                .disabled(isWorking)

                Button("Add first suggestion to board") {
                    applyFirstSuggestion(.addToBoard)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                Button("Prefer more first suggestion") {
                    applyFirstSuggestion(.preferMore)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                Button("Prefer less first suggestion") {
                    applyFirstSuggestion(.preferLess)
                }
                .disabled(isWorking || snapshot?.board.suggestionItems.isEmpty != false)

                if isWorking {
                    DebugCenterProgressRow(text: "Loading Home Board debug state")
                }
                if let message {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Actions")
            } footer: {
                Text("This page exposes the home memory desktop rule inputs, visible cards, user-controlled cards, suggestions, and preference actions before the formal UI polish pass.")
            }

            if let snapshot {
                Section("Rule inputs") {
                    DebugCenterValueRow(title: "Generated", value: snapshot.generatedAt.formatted(.iso8601))
                    DebugCenterValueRow(title: "Date", value: snapshot.date.formatted(.iso8601))
                    DebugCenterValueRow(title: "Limit", value: "\(snapshot.limit)")
                    DebugCenterValueRow(title: "Memories / today / 24h", value: "\(snapshot.input.memoryCount) / \(snapshot.input.todayMemoryCount) / \(snapshot.input.recent24HourMemoryCount)")
                    DebugCenterValueRow(title: "Context / high salience", value: "\(snapshot.input.contextMemoryCount) / \(snapshot.input.highSalienceMemoryCount)")
                    DebugCenterValueRow(title: "Graph links/entities/edges", value: "\(snapshot.input.graphLinkCount) / \(snapshot.input.entityCount) / \(snapshot.input.edgeCount)")
                    DebugCenterValueRow(title: "Accepted arcs active/total", value: "\(snapshot.input.activeAcceptedArcCount) / \(snapshot.input.acceptedArcCount)")
                    DebugCenterValueRow(title: "Reflections suggested/saved", value: "\(snapshot.input.suggestedReflectionCount) / \(snapshot.input.savedReflectionCount)")
                    DebugCenterValueRow(title: "Pipeline running/failed", value: "\(snapshot.input.runningPipelineCount) / \(snapshot.input.failedPipelineCount)")
                }

                Section("Preference counters") {
                    DebugCenterValueRow(title: "Total", value: "\(snapshot.preferences.totalCount)")
                    DebugCenterValueRow(title: "Pinned", value: "\(snapshot.preferences.pinnedCount)")
                    DebugCenterValueRow(title: "Hidden", value: "\(snapshot.preferences.hiddenCount)")
                    DebugCenterValueRow(title: "Dismissed", value: "\(snapshot.preferences.dismissedCount)")
                }

                Section("User board cards") {
                    if snapshot.board.userBoardItems.isEmpty {
                        Text("No user board cards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.board.userBoardItems) { item in
                            DebugHomeBoardItemDiagnosticsRow(item: item, onAction: apply)
                        }
                    }
                }

                Section("Suggestion cards") {
                    if snapshot.board.suggestionItems.isEmpty {
                        Text("No suggestion cards")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.board.suggestionItems) { item in
                            DebugHomeBoardItemDiagnosticsRow(item: item, onAction: apply)
                        }
                    }
                }
            }
        }
        .navigationTitle("Home Board Debug")
        .toolbar {
            Button {
                if let snapshot {
                    UIPasteboard.general.string = buildReport(snapshot)
                    message = "Copied Home Board debug report."
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
        isWorking = true
        defer { isWorking = false }
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
            flags = try memoryRepository.fetchV6FeatureFlags()
            snapshot = try memoryRepository.fetchHomeBoardDebugSnapshot(for: .now, limit: limit)
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func applyFirstSuggestion(_ action: HomeBoardPreferenceAction) {
        guard let item = snapshot?.board.suggestionItems.first else { return }
        apply(item, action)
    }

    @MainActor
    private func apply(_ item: HomeBoardItemSnapshot, _ action: HomeBoardPreferenceAction) {
        do {
            try memoryRepository.updateHomeBoardItemPreference(item, action: action)
            message = "Applied \(debugActionLabel(action)) to \(item.compositionItem.itemKey)."
            snapshot = try memoryRepository.fetchHomeBoardDebugSnapshot(for: .now, limit: limit)
        } catch {
            message = error.localizedDescription
        }
    }

    private func buildReport(_ snapshot: HomeBoardDebugSnapshot) -> String {
        var lines = [
            "=== Mory Home Board Debug ===",
            "Generated: \(snapshot.generatedAt.formatted(.iso8601))",
            "Memories: \(snapshot.input.memoryCount)",
            "Graph: links=\(snapshot.input.graphLinkCount), entities=\(snapshot.input.entityCount), edges=\(snapshot.input.edgeCount)",
            "Preferences: total=\(snapshot.preferences.totalCount), pinned=\(snapshot.preferences.pinnedCount), hidden=\(snapshot.preferences.hiddenCount), dismissed=\(snapshot.preferences.dismissedCount)",
            "",
            "[Cards]",
        ]
        for item in snapshot.board.items {
            lines.append("\(item.layout.layer.rawValue) \(item.cardKind.rawValue) \(debugHomeBoardTitle(item))")
            lines.append("  key=\(item.compositionItem.itemKey)")
            lines.append("  target=\(item.compositionItem.targetType.rawValue)/\(item.compositionItem.targetID.uuidString)")
            lines.append("  span=\(item.layout.span.widthColumns)x\(item.layout.span.heightUnits) priority=\(item.priority)")
            lines.append("  reason=\(item.reason)")
            lines.append("  source_records=\(item.sourceRecordIDs.map(\.uuidString).joined(separator: ","))")
        }
        return lines.joined(separator: "\n")
    }
}

private struct DebugHomeBoardItemDiagnosticsRow: View {
    let item: HomeBoardItemSnapshot
    let onAction: (HomeBoardItemSnapshot, HomeBoardPreferenceAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.cardKind.rawValue)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(item.layout.layer.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(debugHomeBoardTitle(item))
                .font(.subheadline.weight(.semibold))
            Text(item.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
            DebugCenterValueRow(title: "Key", value: item.compositionItem.itemKey)
            DebugCenterValueRow(title: "Target", value: "\(item.compositionItem.targetType.rawValue) · \(item.compositionItem.targetID.uuidString)")
            DebugCenterValueRow(title: "Span / priority", value: "\(item.layout.span.widthColumns)x\(item.layout.span.heightUnits) · \(item.priority)")
            DebugCenterValueRow(title: "Flags", value: "pinned=\(item.isPinned), hidden=\(item.isHidden), dismissed=\(item.dismissedAt?.formatted(.iso8601) ?? "nil")")
            DebugCenterValueRow(title: "Sources", value: item.sourceRecordIDs.isEmpty ? "none" : item.sourceRecordIDs.map(\.uuidString).joined(separator: "\n"))
            HStack {
                Button("Add") { onAction(item, .addToBoard) }
                Button(item.isPinned ? "Unpin" : "Pin") { onAction(item, .pin(!item.isPinned)) }
                Button("More") { onAction(item, .preferMore) }
                Button("Less") { onAction(item, .preferLess) }
                Button("Dismiss") { onAction(item, .dismiss) }
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

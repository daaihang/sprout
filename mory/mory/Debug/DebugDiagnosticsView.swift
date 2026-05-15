import SwiftUI

struct DebugDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var targetType: DebugAnalysisTarget = .memory
    @State private var selectedTargetID: UUID?
    @State private var targetSummary: String = "Latest memory"
    @State private var diagnostics: DebugDiagnosticsSnapshot?
    @State private var recentTargets: [DebugTargetRow] = []
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var errorMessage: String?
    @State private var isSeeding = false
    @State private var isRebuilding = false
    @State private var isReloading = false
    @State private var copiedToast: String?
    @State private var actionLog: [DebugActionLogEntry] = []

    var body: some View {
        List {
            // MARK: - Target Picker

            Section {
                Picker("debug.target.type", selection: $targetType) {
                    ForEach(DebugAnalysisTarget.allCases) { item in
                        Text(item.rawValue.capitalized).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Picker("debug.target.picker", selection: Binding(
                    get: { selectedTargetID?.uuidString ?? "__latest__" },
                    set: { value in
                        selectedTargetID = value == "__latest__" ? nil : UUID(uuidString: value)
                    }
                )) {
                    Text("debug.target.latest").tag("__latest__")
                    ForEach(recentTargets) { item in
                        Text(item.title).tag(item.id.uuidString)
                    }
                }

                if let target = diagnostics?.target {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundStyle(.blue)
                        Text(targetLabel(for: target))
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        copyButton(targetIDText(for: target), label: "ID")
                    }
                }
            } header: {
                Text("debug.section.target")
            }

            // MARK: - Actions

            Section {
                Button {
                    Task { await refreshDiagnostics() }
                } label: {
                    Label(isReloading ? String(localized: "debug.action.loading") : String(localized: "debug.action.refresh"), systemImage: "arrow.clockwise")
                }
                .disabled(isReloading)

                HStack(spacing: 12) {
                    actionButton(String(localized: "debug.action.analysis"), icon: "wand.and.stars", isActive: isRebuilding) {
                        Task { await rebuild(mode: .analysisOnly) }
                    }
                    actionButton(String(localized: "debug.action.graphArcRef"), icon: "point.3.connected.trianglepath.dotted", isActive: isRebuilding) {
                        Task { await rebuild(mode: .graphArcReflection) }
                    }
                    actionButton(String(localized: "debug.action.replay"), icon: "arrow.counterclockwise", isActive: isRebuilding) {
                        Task { await rebuild(mode: .reflectionReplay) }
                    }
                }
                .buttonStyle(.bordered)

                HStack(spacing: 12) {
                    Button {
                        Task { await seedFixtures(count: 1) }
                    } label: {
                        Label(isSeeding ? "..." : String(localized: "debug.action.seed1"), systemImage: "plus.circle")
                    }
                    .disabled(isSeeding)

                    Button {
                        Task { await seedFixtures(count: 3) }
                    } label: {
                        Label(isSeeding ? "..." : String(localized: "debug.action.seed3"), systemImage: "plus.circle.fill")
                    }
                    .disabled(isSeeding)

                    Spacer()

                    Button(role: .destructive) {
                        Task { await clearFixtures() }
                    } label: {
                        Label("debug.action.clear", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            } header: {
                Text("debug.section.actions")
            } footer: {
                Text("debug.action.clear.footer")
            }

            // MARK: - Copy All (for current target)

            if let diagnostics {
                Section {
                    Button {
                        let report = buildFullDebugReport(diagnostics)
                        UIPasteboard.general.string = report
                        showCopiedToast("Full report copied (\(report.count) chars)")
                    } label: {
                        Label("debug.export.copyReport", systemImage: "doc.on.doc.fill")
                            .font(.headline)
                    }
                    .tint(.blue)
                } header: {
                    Text("debug.section.export")
                } footer: {
                    Text("debug.export.footer")
                }
            }

            // MARK: - Error Banner

            if let errorMessage {
                Section {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                        Spacer()
                        copyButton(errorMessage, label: String(localized: "debug.detail.copy"))
                    }
                } header: {
                    Label("debug.section.error", systemImage: "xmark.octagon")
                }
            }

            // MARK: - Action Log

            if !actionLog.isEmpty {
                Section {
                    ForEach(actionLog) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: entry.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(entry.isError ? .red : .green)
                                .font(.caption)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.message)
                                    .font(.caption.monospaced())
                                    .lineLimit(3)
                                Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    Button("debug.action.clearLog", role: .destructive) {
                        actionLog.removeAll()
                    }
                    .font(.caption)
                } header: {
                    Text("Action Log (\(actionLog.count))")
                }
            }

            // MARK: - Diagnostics Detail

            if let diagnostics {

                // Chain Status
                Section {
                    if let fixture = diagnostics.fixture {
                        DebugChainRow(title: String(localized: "debug.chain.record"), isComplete: true,
                                      detail: fixture.recordTitle,
                                      subdetail: "ID: \(fixture.recordID.uuidString)")
                        DebugChainRow(title: String(localized: "debug.chain.artifacts"), isComplete: !fixture.chain.artifacts.isEmpty,
                                      detail: "\(fixture.chain.artifacts.count) item(s)",
                                      subdetail: fixture.chain.artifacts.map { "\($0.kind.rawValue): \($0.title)" }.joined(separator: ", "))
                        DebugChainRow(title: String(localized: "debug.chain.analysis"), isComplete: fixture.chain.analysis != nil,
                                      detail: fixture.chain.pipelineStatus?.userLabel ?? String(localized: "debug.chain.missing"),
                                      subdetail: analysisSubdetail(fixture.chain))
                        DebugChainRow(title: String(localized: "debug.chain.graph"), isComplete: !fixture.chain.entities.isEmpty,
                                      detail: "\(fixture.chain.entities.count) entities / \(fixture.chain.edges.count) edges / \(fixture.chain.links.count) links",
                                      subdetail: fixture.chain.entities.map(\.displayName).joined(separator: ", "))
                        DebugChainRow(title: String(localized: "debug.chain.arc"), isComplete: !fixture.chain.arcs.isEmpty,
                                      detail: fixture.chain.arcs.map(\.title).joined(separator: ", ").ifEmpty(String(localized: "debug.chain.missing")),
                                      subdetail: fixture.chain.arcs.map { "[\($0.status.rawValue)] \($0.id.uuidString.prefix(8))" }.joined(separator: ", "))
                        DebugChainRow(title: String(localized: "debug.chain.reflection"), isComplete: !fixture.chain.reflections.isEmpty,
                                      detail: fixture.chain.reflections.map(\.title).joined(separator: ", ").ifEmpty(String(localized: "debug.chain.missing")),
                                      subdetail: fixture.chain.reflections.map { "[\($0.status.rawValue)] \($0.id.uuidString.prefix(8))" }.joined(separator: ", "))
                    } else {
                        Text("debug.chain.noFixture")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("debug.section.chainStatus")
                }

                // Analyze Payload
                Section {
                    if let analyzePayload = diagnostics.analyzePayload {
                        payloadRow(title: String(localized: "debug.payload.request"), content: analyzePayload.requestBody, recordID: analyzePayload.recordID)
                        payloadRow(title: String(localized: "debug.payload.response"), content: analyzePayload.responseBody.ifEmpty(String(localized: "debug.payload.empty")), recordID: analyzePayload.recordID)
                        if let lastError = analyzePayload.lastError?.trimmedOrNil {
                            errorRow(String(localized: "debug.payload.error"), lastError)
                        }
                        if let rawErrorBody = analyzePayload.rawErrorBody?.trimmedOrNil {
                            payloadRow(title: String(localized: "debug.payload.rawErrorBody"), content: rawErrorBody, recordID: analyzePayload.recordID)
                        }
                        copyAllPayloadButton("Analyze", analyzePayload: analyzePayload)
                    } else {
                        Text("debug.payload.noAnalysis")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("debug.section.analyzePayload")
                }

                // Reflection Payload
                Section {
                    if let reflectionPayload = diagnostics.reflectionPayload {
                        payloadRow(title: String(localized: "debug.payload.request"), content: reflectionPayload.requestBody, recordID: reflectionPayload.recordID)
                        payloadRow(title: String(localized: "debug.payload.response"), content: reflectionPayload.responseBody.ifEmpty(String(localized: "debug.payload.empty")), recordID: reflectionPayload.recordID)
                        if let lastError = reflectionPayload.lastError?.trimmedOrNil {
                            errorRow(String(localized: "debug.payload.error"), lastError)
                        }
                        if let rawErrorBody = reflectionPayload.rawErrorBody?.trimmedOrNil {
                            payloadRow(title: String(localized: "debug.payload.rawErrorBody"), content: rawErrorBody, recordID: reflectionPayload.recordID)
                        }
                        copyAllPayloadButton("Reflection", reflectionPayload: reflectionPayload)
                    } else {
                        Text("debug.payload.noReflection")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("debug.section.reflectionPayload")
                }

                // Pipeline Trace
                Section {
                    if let pipelineTrace = diagnostics.pipelineTrace {
                        if let failedStage = pipelineTrace.failedStage?.trimmedOrNil {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Failed Stage: \(failedStage)")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        if let statusCode = pipelineTrace.statusCode {
                            HStack {
                                Text("debug.pipeline.httpStatus")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(statusCode)")
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(statusCode >= 400 ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        if let requestBody = pipelineTrace.requestBody?.trimmedOrNil {
                            payloadRow(title: String(localized: "debug.pipeline.pipelineRequest"), content: requestBody, recordID: nil)
                        }
                        if let responseBody = pipelineTrace.responseBody?.trimmedOrNil {
                            payloadRow(title: String(localized: "debug.pipeline.pipelineResponse"), content: responseBody, recordID: nil)
                        }
                        if let rawErrorBody = pipelineTrace.rawErrorBody?.trimmedOrNil {
                            payloadRow(title: String(localized: "debug.pipeline.pipelineError"), content: rawErrorBody, recordID: nil)
                        }
                        Button {
                            let text = buildPipelineTraceReport(pipelineTrace)
                            UIPasteboard.general.string = text
                            showCopiedToast("Pipeline trace copied")
                        } label: {
                            Label("debug.pipeline.copyTrace", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                    } else {
                        Text("debug.pipeline.noTrace")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("debug.section.pipelineTrace")
                }

                // Provenance
                Section {
                    if diagnostics.provenance.isEmpty {
                        Text("debug.provenance.empty")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(diagnostics.provenance, id: \.entityID) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.entityID.uuidString.prefix(8) + "...")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    copyButton(item.entityID.uuidString, label: "ID")
                                }
                                HStack(spacing: 8) {
                                    badge("aliases", count: item.aliasCount)
                                    badge("records", count: item.provenanceRecordIDs.count)
                                    badge("artifacts", count: item.linkedArtifactIDs.count)
                                    badge("analyses", count: item.linkedAnalysisRecordIDs.count)
                                }
                                if !item.evidenceSummary.isEmpty {
                                    Text(item.evidenceSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("debug.section.provenance") + Text(" (\(diagnostics.provenance.count))")
                }

                // Pipeline Status List
                Section {
                    if pipelineStatuses.isEmpty {
                        Text("debug.pipeline.noPipelines")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pipelineStatuses) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Spacer()
                                    pipelineStageBadge(item.status.stage)
                                }
                                HStack(spacing: 8) {
                                    Text(item.recordID.uuidString.prefix(8) + "...")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.tertiary)
                                    if let lastAttempt = item.status.lastAttemptAt {
                                        Text(lastAttempt.formatted(date: .omitted, time: .standard))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                if let lastError = item.status.lastError?.trimmedOrNil {
                                    Text(lastError)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .lineLimit(2)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("debug.section.allPipelines") + Text(" (\(pipelineStatuses.count))")
                }
            }

            // MARK: - Language Settings

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("debug.settings.language", systemImage: "globe")
                }
            } footer: {
                Text("debug.settings.languageFooter")
            }
        }
        .navigationTitle("debug.title")
        .overlay(alignment: .bottom) {
            if let copiedToast {
                Text(copiedToast)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .shadow(radius: 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: copiedToast)
        .task {
            await autoRefresh()
        }
        .onChange(of: targetType) { _, _ in
            Task { await refreshDiagnostics() }
        }
        .onChange(of: selectedTargetID) { _, _ in
            Task { await refreshDiagnostics() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func payloadRow(title: String, content: String, recordID: UUID?) -> some View {
        NavigationLink {
            PayloadDetailView(title: title, content: content, recordID: recordID)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(payloadPreview(content))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(content.count)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func errorRow(_ label: String, _ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            VStack(alignment: .leading) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption.monospaced())
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }
            Spacer()
            copyButton(message, label: String(localized: "debug.detail.copy"))
        }
    }

    @ViewBuilder
    private func copyAllPayloadButton(
        _ label: String,
        analyzePayload: DebugAnalyzePayloadSnapshot? = nil,
        reflectionPayload: DebugReflectionPayloadSnapshot? = nil
    ) -> some View {
        Button {
            var text = "=== \(label) Debug Export ===\n"
            text += "Exported: \(Date.now.formatted(.iso8601))\n\n"
            if let p = analyzePayload {
                text += "--- Record ID ---\n\(p.recordID.uuidString)\n\n"
                text += "--- Request Body ---\n\(prettyJSON(p.requestBody))\n\n"
                text += "--- Response Body ---\n\(prettyJSON(p.responseBody))\n\n"
                if let e = p.lastError?.trimmedOrNil { text += "--- Error ---\n\(e)\n\n" }
                if let r = p.rawErrorBody?.trimmedOrNil { text += "--- Raw Error Body ---\n\(r)\n\n" }
            }
            if let p = reflectionPayload {
                if let rid = p.recordID { text += "--- Record ID ---\n\(rid.uuidString)\n\n" }
                if let aid = p.arcID { text += "--- Arc ID ---\n\(aid.uuidString)\n\n" }
                text += "--- Request Body ---\n\(prettyJSON(p.requestBody))\n\n"
                text += "--- Response Body ---\n\(prettyJSON(p.responseBody))\n\n"
                if let e = p.lastError?.trimmedOrNil { text += "--- Error ---\n\(e)\n\n" }
                if let r = p.rawErrorBody?.trimmedOrNil { text += "--- Raw Error Body ---\n\(r)\n\n" }
            }
            UIPasteboard.general.string = text
            showCopiedToast("\(label) payloads copied (\(text.count) chars)")
        } label: {
            Label("Copy All \(label) Payloads", systemImage: "doc.on.doc")
                .font(.caption)
        }
    }

    @ViewBuilder
    private func actionButton(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(isActive ? "..." : title, systemImage: icon)
                .font(.caption)
                .lineLimit(1)
        }
        .disabled(isActive)
    }

    @ViewBuilder
    private func copyButton(_ text: String, label: String) -> some View {
        Button {
            UIPasteboard.general.string = text
            showCopiedToast("\(label) copied")
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .tint(.secondary)
    }

    @ViewBuilder
    private func badge(_ label: String, count: Int) -> some View {
        Text("\(count) \(label)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(count > 0 ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func pipelineStageBadge(_ stage: MemoryPipelineStage) -> some View {
        Text(stage.rawValue)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(pipelineStageColor(stage).opacity(0.15))
            .foregroundStyle(pipelineStageColor(stage))
            .clipShape(Capsule())
    }

    // MARK: - Actions

    @MainActor
    private func autoRefresh() async {
        await refreshDiagnostics()

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { break }
            await refreshDiagnostics()
        }
    }

    @MainActor
    private func refreshDiagnostics() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            let selected = try resolveSelectedTarget()
            selectedTargetID = selected.id
            targetSummary = selected.title
            diagnostics = try memoryRepository.fetchDebugDiagnostics(targetType: targetType, targetID: selectedTargetID)
            recentTargets = try fetchRecentTargets(for: targetType)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rebuild(mode: DebugRebuildMode) async {
        guard !isRebuilding else { return }
        isRebuilding = true
        defer { isRebuilding = false }

        let modeLabel: String
        switch mode {
        case .analysisOnly: modeLabel = "Analysis Only"
        case .graphArcReflection: modeLabel = "Graph+Arc+Reflection"
        case .reflectionReplay: modeLabel = "Reflection Replay"
        }

        appendLog("Starting \(modeLabel)...")
        do {
            try await memoryRepository.rerunDebugPipeline(targetType: targetType, targetID: selectedTargetID, mode: mode)
            appendLog("\(modeLabel) completed successfully")
            await refreshDiagnostics()
        } catch {
            appendLog("\(modeLabel) failed: \(error.localizedDescription)", isError: true)
            errorMessage = error.localizedDescription
        }
    }

    private func seedFixtures(count: Int) async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }

        appendLog("Seeding \(count) fixture(s)...")
        do {
            let fixtures = try await memoryRepository.seedDebugFixtures(count: count)
            appendLog("Seeded \(fixtures.count) fixture(s): \(fixtures.map(\.recordTitle).joined(separator: ", "))")
            await refreshDiagnostics()
        } catch {
            appendLog("Seed failed: \(error.localizedDescription)", isError: true)
            errorMessage = error.localizedDescription
        }
    }

    private func clearFixtures() async {
        appendLog("Clearing debug fixtures...")
        do {
            try memoryRepository.clearDebugFixtures()
            appendLog("Debug fixtures cleared")
            selectedTargetID = nil
            await refreshDiagnostics()
        } catch {
            appendLog("Clear failed: \(error.localizedDescription)", isError: true)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func resolveSelectedTarget() throws -> DebugTargetRow {
        let rows = try fetchRecentTargets(for: targetType)
        if let selectedTargetID, let match = rows.first(where: { $0.id == selectedTargetID }) {
            return match
        }
        if let first = rows.first {
            return first
        }
        throw CocoaError(.fileNoSuchFile)
    }

    private func fetchRecentTargets(for targetType: DebugAnalysisTarget) throws -> [DebugTargetRow] {
        switch targetType {
        case .memory:
            return try memoryRepository.fetchRecentMemories(limit: 8).map {
                DebugTargetRow(id: $0.record.id, title: $0.title)
            }
        case .arc:
            return try memoryRepository.fetchTemporalArcSummaries(limit: 8).map {
                DebugTargetRow(id: $0.arc.id, title: $0.arc.title)
            }
        case .reflection:
            return try memoryRepository.fetchReflectionSummaries(limit: 8).map {
                DebugTargetRow(id: $0.reflection.id, title: $0.reflection.title)
            }
        }
    }

    private func targetLabel(for snapshot: DebugTargetSnapshot) -> String {
        switch snapshot.targetType {
        case .memory:
            return snapshot.memory?.title ?? "Memory"
        case .arc:
            return snapshot.arc?.arc.title ?? "Arc"
        case .reflection:
            return snapshot.reflection?.reflection.title ?? "Reflection"
        }
    }

    private func targetIDText(for snapshot: DebugTargetSnapshot) -> String {
        switch snapshot.targetType {
        case .memory:
            return snapshot.memory?.record.id.uuidString ?? ""
        case .arc:
            return snapshot.arc?.arc.id.uuidString ?? ""
        case .reflection:
            return snapshot.reflection?.reflection.id.uuidString ?? ""
        }
    }

    private func analysisSubdetail(_ chain: DebugMemoryChainSnapshot) -> String {
        guard let analysis = chain.analysis else { return String(localized: "debug.chain.noAnalysis") }
        var parts: [String] = []
        if !analysis.themes.isEmpty { parts.append("themes: \(analysis.themes.joined(separator: ", "))") }
        if analysis.salienceScore != nil { parts.append("salience: \(String(format: "%.2f", analysis.salienceScore ?? 0))") }
        parts.append("\(analysis.entityMentions.count) mentions")
        parts.append("\(analysis.candidateEdges.count) candidate edges")
        return parts.joined(separator: " | ")
    }

    private func showCopiedToast(_ message: String) {
        copiedToast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copiedToast = nil
        }
    }

    private func appendLog(_ message: String, isError: Bool = false) {
        actionLog.insert(DebugActionLogEntry(message: message, isError: isError, timestamp: .now), at: 0)
        if actionLog.count > 30 { actionLog.removeLast() }
    }

    private func payloadPreview(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "debug.payload.empty") }
        let firstLine = trimmed.prefix(120)
        return String(firstLine) + (trimmed.count > 120 ? "..." : "")
    }

    private func pipelineStageColor(_ stage: MemoryPipelineStage) -> Color {
        switch stage {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }

    // MARK: - Full Report Builder

    private func buildFullDebugReport(_ diag: DebugDiagnosticsSnapshot) -> String {
        var lines: [String] = []
        lines.append("========================================")
        lines.append("  MORY DEBUG REPORT")
        lines.append("  Generated: \(Date.now.formatted(.iso8601))")
        lines.append("========================================\n")

        if let target = diag.target {
            lines.append("--- TARGET ---")
            lines.append("Type: \(target.targetType.rawValue)")
            lines.append("Label: \(targetLabel(for: target))")
            lines.append("ID: \(targetIDText(for: target))")
            lines.append("")
        }

        if let fixture = diag.fixture {
            lines.append("--- CHAIN STATUS ---")
            lines.append("Record:     \(fixture.recordID.uuidString)")
            lines.append("  Title:    \(fixture.recordTitle)")
            lines.append("  RawText:  \(fixture.chain.record.rawText.prefix(200))")
            lines.append("Artifacts:  \(fixture.chain.artifacts.count)")
            for a in fixture.chain.artifacts {
                lines.append("  [\(a.kind.rawValue)] \(a.title) — \(a.summary.prefix(80))")
            }
            lines.append("Analysis:   \(fixture.chain.analysis != nil ? "YES" : "NO")")
            if let analysis = fixture.chain.analysis {
                lines.append("  Themes:   \(analysis.themes.joined(separator: ", "))")
                lines.append("  Emotion:  \(analysis.emotionInterpretation)")
                lines.append("  Salience: \(analysis.salienceScore.map { String(format: "%.2f", $0) } ?? "nil")")
                lines.append("  Mentions: \(analysis.entityMentions.count)")
                lines.append("  CandEdges:\(analysis.candidateEdges.count)")
                lines.append("  RetTerms: \(analysis.retrievalTerms.joined(separator: ", "))")
            }
            lines.append("Pipeline:   \(fixture.chain.pipelineStatus?.stage.rawValue ?? "nil")")
            if let ps = fixture.chain.pipelineStatus {
                lines.append("  UserLabel:  \(ps.userLabel)")
                if let err = ps.lastError?.trimmedOrNil { lines.append("  Error:      \(err)") }
                if let code = ps.lastHTTPStatusCode { lines.append("  HTTPStatus: \(code)") }
                if let stage = ps.failedStage?.trimmedOrNil { lines.append("  FailedStage:\(stage)") }
                if let at = ps.lastAttemptAt { lines.append("  LastAttempt:\(at.formatted(.iso8601))") }
                if let at = ps.completedAt { lines.append("  Completed:  \(at.formatted(.iso8601))") }
            }
            lines.append("Entities:   \(fixture.chain.entities.count)")
            for e in fixture.chain.entities {
                lines.append("  [\(e.kind.rawValue)] \(e.displayName) (\(e.id.uuidString.prefix(8)))")
            }
            lines.append("Edges:      \(fixture.chain.edges.count)")
            lines.append("Links:      \(fixture.chain.links.count)")
            lines.append("Arcs:       \(fixture.chain.arcs.count)")
            for a in fixture.chain.arcs {
                lines.append("  [\(a.status.rawValue)] \(a.title) (\(a.id.uuidString.prefix(8)))")
            }
            lines.append("Reflections:\(fixture.chain.reflections.count)")
            for r in fixture.chain.reflections {
                lines.append("  [\(r.status.rawValue)] \(r.title) (\(r.id.uuidString.prefix(8)))")
            }
            lines.append("")
        }

        if let p = diag.analyzePayload {
            lines.append("--- ANALYZE PAYLOAD ---")
            lines.append("Record ID: \(p.recordID.uuidString)")
            lines.append("")
            lines.append("[Request Body]")
            lines.append(prettyJSON(p.requestBody))
            lines.append("")
            lines.append("[Response Body]")
            lines.append(prettyJSON(p.responseBody))
            if let e = p.lastError?.trimmedOrNil {
                lines.append("")
                lines.append("[Error] \(e)")
            }
            if let r = p.rawErrorBody?.trimmedOrNil {
                lines.append("")
                lines.append("[Raw Error Body]")
                lines.append(r)
            }
            lines.append("")
        }

        if let p = diag.reflectionPayload {
            lines.append("--- REFLECTION PAYLOAD ---")
            if let rid = p.recordID { lines.append("Record ID: \(rid.uuidString)") }
            if let aid = p.arcID { lines.append("Arc ID:    \(aid.uuidString)") }
            lines.append("")
            lines.append("[Request Body]")
            lines.append(prettyJSON(p.requestBody))
            lines.append("")
            lines.append("[Response Body]")
            lines.append(prettyJSON(p.responseBody))
            if let e = p.lastError?.trimmedOrNil {
                lines.append("")
                lines.append("[Error] \(e)")
            }
            if let r = p.rawErrorBody?.trimmedOrNil {
                lines.append("")
                lines.append("[Raw Error Body]")
                lines.append(r)
            }
            lines.append("")
        }

        if let t = diag.pipelineTrace {
            lines.append("--- PIPELINE TRACE ---")
            if let s = t.failedStage?.trimmedOrNil { lines.append("Failed Stage: \(s)") }
            if let c = t.statusCode { lines.append("HTTP Status:  \(c)") }
            if let r = t.requestBody?.trimmedOrNil {
                lines.append("[Pipeline Request]")
                lines.append(prettyJSON(r))
            }
            if let r = t.responseBody?.trimmedOrNil {
                lines.append("[Pipeline Response]")
                lines.append(prettyJSON(r))
            }
            if let r = t.rawErrorBody?.trimmedOrNil {
                lines.append("[Pipeline Error Body]")
                lines.append(r)
            }
            lines.append("")
        }

        if !diag.provenance.isEmpty {
            lines.append("--- PROVENANCE (\(diag.provenance.count) entities) ---")
            for p in diag.provenance {
                lines.append("Entity: \(p.entityID.uuidString)")
                lines.append("  Aliases: \(p.aliasCount), Records: \(p.provenanceRecordIDs.count), Artifacts: \(p.linkedArtifactIDs.count)")
                if !p.evidenceSummary.isEmpty { lines.append("  Evidence: \(p.evidenceSummary)") }
            }
            lines.append("")
        }

        lines.append("========================================")
        lines.append("  END OF DEBUG REPORT")
        lines.append("========================================")
        return lines.joined(separator: "\n")
    }

    private func buildPipelineTraceReport(_ trace: DebugPipelineTraceSnapshot) -> String {
        var lines: [String] = ["--- Pipeline Trace ---"]
        if let s = trace.failedStage?.trimmedOrNil { lines.append("Failed Stage: \(s)") }
        if let c = trace.statusCode { lines.append("HTTP Status:  \(c)") }
        if let r = trace.requestBody?.trimmedOrNil { lines.append("\n[Request]\n\(prettyJSON(r))") }
        if let r = trace.responseBody?.trimmedOrNil { lines.append("\n[Response]\n\(prettyJSON(r))") }
        if let r = trace.rawErrorBody?.trimmedOrNil { lines.append("\n[Error Body]\n\(r)") }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Pretty JSON Helper

private func prettyJSON(_ raw: String) -> String {
    guard let data = raw.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let result = String(data: pretty, encoding: .utf8)
    else {
        return raw
    }
    return result
}

// MARK: - Payload Detail View (full-screen viewer)

private struct PayloadDetailView: View {
    let title: String
    let content: String
    let recordID: UUID?

    @State private var showPretty = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if recordID != nil {
                    Text(recordID!.uuidString.prefix(8) + "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(displayContent.count) chars")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Toggle("debug.detail.pretty", isOn: $showPretty)
                    .toggleStyle(.button)
                    .font(.caption)
                Button {
                    UIPasteboard.general.string = displayContent
                } label: {
                    Label("debug.detail.copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                ShareLink(item: displayContent) {
                    Label("debug.detail.share", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            ScrollView([.horizontal, .vertical]) {
                Text(verbatim: displayContent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayContent: String {
        showPretty ? prettyJSON(content) : content
    }
}

// MARK: - Supporting Types

private struct DebugTargetRow: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
}

private struct DebugActionLogEntry: Identifiable {
    let id = UUID()
    let message: String
    let isError: Bool
    let timestamp: Date
}

private struct DebugChainRow: View {
    let title: String
    let isComplete: Bool
    let detail: String
    var subdetail: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(isComplete ? .green : .orange)
                .font(.callout)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !subdetail.isEmpty {
                    Text(subdetail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

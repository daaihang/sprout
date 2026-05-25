#if DEBUG
import SwiftUI
import SwiftData

struct DebugQualityTuningLabView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var scenarioID: QualityTuningScenarioID = .ordinaryShortText
    @State private var promptProfile: QualityTuningPromptProfile = QualityTuningRuntime.promptProfile
    @State private var thresholds: QualityTuningThresholds = QualityTuningRuntime.thresholds
    @State private var customTitle = ""
    @State private var customBody = ""
    @State private var customMood = ""
    @State private var customContext = ""
    @State private var isRunning = false
    @State private var latestReport: QualityTuningRunReport?
    @State private var reports: [QualityTuningRunReport] = []
    @State private var errorMessage: String?
    @State private var copiedToast: String?
    @State private var preference: QualityTuningPreference = .defaults

    var body: some View {
        List {
            Section {
                Picker("Scenario", selection: $scenarioID) {
                    ForEach(QualityTuningScenarioID.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("Prompt profile", selection: $promptProfile) {
                    ForEach(QualityTuningPromptProfile.allCases) { item in
                        Text(item.rawValue.capitalized).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                Text("Runs use the real memory repository and will appear in Home, Timeline, Search, Arcs, and Reflections.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                LabeledContent("Runtime override") {
                    Text(QualityTuningRuntime.isEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(QualityTuningRuntime.isEnabled ? .orange : .secondary)
                }
                Button {
                    QualityTuningRuntime.isEnabled = false
                    QualityTuningRuntime.thresholds = .defaults
                    thresholds = .defaults
                    promptProfile = .balanced
                    QualityTuningRuntime.promptProfile = .balanced
                } label: {
                    Label("Disable tuning runtime", systemImage: "power")
                }
                Button {
                    Task { await saveCurrentPreference() }
                } label: {
                    Label("Save Local Preference", systemImage: "tray.and.arrow.down")
                }
            } header: {
                Text("Quality Tuning Lab")
            } footer: {
                Text("Preference: \(preference.syncKey) · schema \(preference.schemaVersion) · \(preference.updatedAt.formatted(date: .abbreviated, time: .shortened))")
            }

            Section {
                Button {
                    Task { await runSelectedScenario() }
                } label: {
                    Label(isRunning ? "Running..." : "Run Selected Scenario", systemImage: "play.circle")
                }
                .disabled(isRunning)
                Button {
                    Task { await runCoreBatch() }
                } label: {
                    Label(isRunning ? "Running..." : "Run Core Batch", systemImage: "checklist.checked")
                }
                .disabled(isRunning)
                Button {
                    Task { await runAllScenarios() }
                } label: {
                    Label(isRunning ? "Running..." : "Run All Presets", systemImage: "play.circle.fill")
                }
                .disabled(isRunning)
                Button {
                    Task { await runStrictBalancedMatrix() }
                } label: {
                    Label(isRunning ? "Running..." : "Run Strict + Balanced Matrix", systemImage: "square.grid.2x2")
                }
                .disabled(isRunning)
                if !reports.isEmpty {
                    Button {
                        UIPasteboard.general.string = reports.map(\.exportText).joined(separator: "\n\n")
                        showCopiedToast("All tuning reports copied")
                    } label: {
                        Label("Copy All Reports", systemImage: "doc.on.doc.fill")
                    }
                }
                Button(role: .destructive) {
                    Task { await clearLabData() }
                } label: {
                    Label("Clear Lab Data", systemImage: "trash")
                }
                .disabled(isRunning)
            } header: {
                Text("Execution")
            } footer: {
                Text("Core Batch runs strict, balanced, and experimental profiles over the high-signal input and history scenarios.")
            }

            Section {
                TextField("Custom title override", text: $customTitle)
                TextField("Custom body override", text: $customBody, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Custom mood override", text: $customMood)
                TextField("Custom context override", text: $customContext, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Custom Content")
            } footer: {
                Text("Leave fields empty to use the selected preset.")
            }

            Section {
                thresholdSlider("Entity confidence", value: $thresholds.entityMinimumConfidence, range: 0.1...0.95)
                thresholdSlider("Theme / decision confidence", value: $thresholds.themeDecisionMinimumConfidence, range: 0.1...0.95)
                Stepper("Arc min records: \(thresholds.arcMinimumRecordCount)", value: $thresholds.arcMinimumRecordCount, in: 1...5)
                thresholdSlider("Arc cluster strength", value: $thresholds.arcMinimumClusterStrength, range: 0.1...0.95)
                thresholdSlider("Arc intensity", value: $thresholds.arcMinimumIntensityScore, range: 0.5...10)
                thresholdSlider("Arc average salience", value: $thresholds.arcMinimumAverageSalience, range: 0.1...0.95)
                thresholdSlider("Reflection salience", value: $thresholds.reflectionMinimumRecordSalience, range: 0.1...0.95)
                Stepper("Reflection evidence chars: \(thresholds.reflectionMinimumEvidenceCharacters)", value: $thresholds.reflectionMinimumEvidenceCharacters, in: 0...500, step: 10)
                thresholdSlider("Reflection confidence", value: $thresholds.reflectionMinimumResultConfidence, range: 0.1...0.95)
                Button {
                    thresholds = .defaults
                    QualityTuningRuntime.thresholds = thresholds
                } label: {
                    Label("Reset defaults", systemImage: "arrow.counterclockwise")
                }
            } header: {
                Text("Local Gate Overrides")
            } footer: {
                Text(thresholds.summary)
                    .font(.caption.monospaced())
            }

            Section {
                Button {
                    Task { await runSelectedScenario() }
                } label: {
                    Label(isRunning ? "Running..." : "Run Selected Scenario", systemImage: "play.circle")
                }
                .disabled(isRunning)
                Button {
                    Task { await runAllScenarios() }
                } label: {
                    Label(isRunning ? "Running..." : "Run All Presets", systemImage: "play.circle.fill")
                }
                .disabled(isRunning)
                Button {
                    Task { await runStrictBalancedMatrix() }
                } label: {
                    Label(isRunning ? "Running..." : "Run Strict + Balanced Matrix", systemImage: "square.grid.2x2")
                }
                .disabled(isRunning)
            } footer: {
                Text("Each run creates real local memories and calls the configured Go API through the normal pipeline.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption.monospaced())
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                } header: {
                    Label("Error", systemImage: "exclamationmark.triangle")
                }
            }

            if let latestReport {
                reportSection(latestReport, title: "Latest Report")
            }

            if !reports.isEmpty {
                Section {
                    Button {
                        UIPasteboard.general.string = reports.map(\.exportText).joined(separator: "\n\n")
                        showCopiedToast("All tuning reports copied")
                    } label: {
                        Label("Copy All Reports", systemImage: "doc.on.doc.fill")
                    }
                    ForEach(reports) { report in
                        NavigationLink {
                            DebugQualityTuningReportView(report: report)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(report.scenarioTitle)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(report.expectationPassed ? "PASS" : "FAIL")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(report.expectationPassed ? .green : .red)
                                }
                                Text(report.recordIDs.map { $0.uuidString.prefix(8) }.joined(separator: ", "))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Run History")
                }
            }
        }
        .navigationTitle("Quality Tuning Lab")
        .task {
            await loadPreference()
        }
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
    }

    @ViewBuilder
    private func thresholdSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(2))))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    @ViewBuilder
    private func reportSection(_ report: QualityTuningRunReport, title: String) -> some View {
        Section {
            DebugQualityTuningReportBody(report: report)
            Button {
                UIPasteboard.general.string = report.exportText
                showCopiedToast("Tuning report copied")
            } label: {
                Label("Copy Full Report", systemImage: "doc.on.doc")
            }
        } header: {
            Text(title)
        }
    }

    private func runSelectedScenario() async {
        await runScenario(makeScenario())
    }

    private func runAllScenarios() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        for id in QualityTuningScenarioID.allCases {
            do {
                let report = try await memoryRepository.runQualityTuningScenario(
                    QualityTuningRunRequest(
                        scenario: QualityTuningScenario.preset(id),
                        promptProfile: promptProfile,
                        thresholds: thresholds
                    )
                )
                latestReport = report
                reports.insert(report, at: 0)
            } catch {
                errorMessage = "\(id.title): \(error.localizedDescription)"
                break
            }
        }
    }

    private func runCoreBatch() async {
        guard !isRunning else { return }
        let ids = QualityTuningScenarioID.allCases
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        for profile in QualityTuningPromptProfile.allCases {
            for id in ids {
                do {
                    let report = try await memoryRepository.runQualityTuningScenario(
                        QualityTuningRunRequest(
                            scenario: QualityTuningScenario.preset(id),
                            promptProfile: profile,
                            thresholds: thresholds
                        )
                    )
                    latestReport = report
                    reports.insert(report, at: 0)
                } catch {
                    errorMessage = "\(profile.rawValue) / \(id.title): \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    private func runStrictBalancedMatrix() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        for profile in QualityTuningPromptProfile.allCases {
            for id in QualityTuningScenarioID.allCases {
                do {
                    let report = try await memoryRepository.runQualityTuningScenario(
                        QualityTuningRunRequest(
                            scenario: QualityTuningScenario.preset(id),
                            promptProfile: profile,
                            thresholds: thresholds
                        )
                    )
                    latestReport = report
                    reports.insert(report, at: 0)
                } catch {
                    errorMessage = "\(profile.rawValue) / \(id.title): \(error.localizedDescription)"
                    return
                }
            }
        }
    }

    private func loadPreference() async {
        do {
            let loaded = try memoryRepository.fetchQualityTuningPreference()
            preference = loaded
            promptProfile = loaded.promptProfile
            thresholds = loaded.thresholds
            QualityTuningRuntime.promptProfile = loaded.promptProfile
            QualityTuningRuntime.thresholds = loaded.thresholds
        } catch {
            errorMessage = "Load tuning preference: \(error.localizedDescription)"
        }
    }

    private func saveCurrentPreference() async {
        do {
            var updated = preference
            updated.promptProfile = promptProfile
            updated.thresholds = thresholds
            updated.updatedAt = .now
            try memoryRepository.saveQualityTuningPreference(updated)
            preference = updated
            QualityTuningRuntime.promptProfile = promptProfile
            QualityTuningRuntime.thresholds = thresholds
            showCopiedToast("Local tuning preference saved")
        } catch {
            errorMessage = "Save tuning preference: \(error.localizedDescription)"
        }
    }

    private func clearLabData() async {
        do {
            try memoryRepository.clearAllLocalData()
            latestReport = nil
            reports.removeAll()
            showCopiedToast("Lab data cleared")
        } catch {
            errorMessage = "Clear lab data: \(error.localizedDescription)"
        }
    }

    private func runScenario(_ scenario: QualityTuningScenario) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        do {
            let report = try await memoryRepository.runQualityTuningScenario(
                QualityTuningRunRequest(
                    scenario: scenario,
                    promptProfile: promptProfile,
                    thresholds: thresholds
                )
            )
            latestReport = report
            reports.insert(report, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func makeScenario() -> QualityTuningScenario {
        var scenario = QualityTuningScenario.preset(scenarioID)
        if let title = customTitle.trimmedOrNil { scenario.title = title }
        if let body = customBody.trimmedOrNil {
            scenario.body = body
            scenario.artifacts = [.text(title: scenario.title, body: body)]
        }
        if let mood = customMood.trimmedOrNil { scenario.mood = mood }
        if let context = customContext.trimmedOrNil { scenario.context = context }
        return scenario
    }

    private func showCopiedToast(_ message: String) {
        copiedToast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if copiedToast == message {
                    copiedToast = nil
                }
            }
        }
    }
}

struct DebugQualityTuningReportView: View {
    let report: QualityTuningRunReport

    var body: some View {
        List {
            Section {
                DebugQualityTuningReportBody(report: report)
                Button {
                    UIPasteboard.general.string = report.exportText
                } label: {
                    Label("Copy Full Report", systemImage: "doc.on.doc")
                }
            }
            Section("Request") {
                Text(report.requestBody.ifEmpty("Empty"))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            Section("Raw Response") {
                Text(report.rawResponseBody.ifEmpty("Empty"))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(report.scenarioTitle)
    }
}

struct DebugQualityTuningReportBody: View {
    let report: QualityTuningRunReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.scenarioTitle)
                    .font(.headline)
                Spacer()
                Text(report.expectationPassed ? "PASS" : "FAIL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(report.expectationPassed ? .green : .red)
            }
            Text("Profile: \(report.promptProfile.rawValue)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("Expectation: \(report.expectation.rawValue)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("Records: \(report.recordIDs.map { $0.uuidString.prefix(8) }.joined(separator: ", "))")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text("Request ID: \(report.requestID ?? "none")")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(report.thresholdsSummary)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Divider()
            ForEach(report.gates) { gate in
                HStack(alignment: .top) {
                    Image(systemName: gate.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(gate.passed ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gate.title)
                            .font(.caption.weight(.semibold))
                        Text(gate.detail)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            Text("Filtered")
                .font(.caption.weight(.semibold))
            Text(report.filteredSummary)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Text("Stored")
                .font(.caption.weight(.semibold))
            Text(report.storedSummary)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
#endif

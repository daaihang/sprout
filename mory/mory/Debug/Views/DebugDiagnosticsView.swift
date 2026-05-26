import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import Photos
import AVFoundation
import Speech
import MusicKit

struct DebugDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    init(
        authManager: AuthSessionManager? = nil,
        runtimeEnvironment: AppRuntimeEnvironment = .current
    ) {
        self.authManager = authManager
        self.runtimeEnvironment = runtimeEnvironment
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DebugEnvironmentView(runtimeEnvironment: runtimeEnvironment)
                } label: {
                    DebugMenuRow(
                        icon: "shippingbox",
                        title: String(localized: "debug.menu.environment"),
                        subtitle: runtimeEnvironment.label
                    )
                }

                NavigationLink {
                    DebugAuthSessionView(authManager: authManager)
                } label: {
                    DebugMenuRow(
                        icon: "person.badge.key",
                        title: String(localized: "debug.menu.auth"),
                        subtitle: String(localized: "debug.menu.auth.subtitle")
                    )
                }

                NavigationLink {
                    DebugLocalDataVaultView()
                } label: {
                    DebugMenuRow(
                        icon: "externaldrive.badge.person.crop",
                        title: "Local Data Vault",
                        subtitle: "Inspect active owner, SwiftData store, legacy claim, and UserDefaults scope decisions"
                    )
                }

                NavigationLink {
                    DebugV6ControlsView()
                } label: {
                    DebugMenuRow(
                        icon: "slider.horizontal.3",
                        title: "V6 Controls",
                        subtitle: "Edit V6 flags, AI preferences, and effective gate diagnostics"
                    )
                }

                NavigationLink {
                    DebugCloudIntelligenceView()
                } label: {
                    DebugMenuRow(
                        icon: "icloud",
                        title: "Cloud Intelligence",
                        subtitle: "Trigger V6 cloud requests and inspect request IDs, model metadata, results, and errors"
                    )
                }

                NavigationLink {
                    BackgroundManagementView()
                } label: {
                    DebugMenuRow(
                        icon: "clock.arrow.circlepath",
                        title: "Background Operations",
                        subtitle: "Inspect unified background triggers, operation runs, notification handoffs, and debug simulations"
                    )
                }

                NavigationLink {
                    DebugJobQueueView()
                } label: {
                    DebugMenuRow(
                        icon: "list.bullet",
                        title: "Job Queue",
                        subtitle: "Inspect V6 jobs, notification intents, graph deltas, recovery, and due worker execution"
                    )
                }

                NavigationLink {
                    DebugSemanticSearchView()
                } label: {
                    DebugMenuRow(
                        icon: "magnifyingglass",
                        title: "Semantic Search",
                        subtitle: "Run exact and semantic search, rebuild Core Spotlight, and inspect retrieval source state"
                    )
                }

                NavigationLink {
                    DebugAnalysisContextPackView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.stack.badge.person.crop",
                        title: "Analysis Context Pack",
                        subtitle: "Build the Analysis context pack for the latest memory and inspect budget, privacy, and evidence"
                    )
                }

                NavigationLink {
                    DebugPersonProfileView()
                } label: {
                    DebugMenuRow(
                        icon: "person.crop.rectangle.stack",
                        title: "Person Profiles",
                        subtitle: "Inspect Analysis PersonProfile, portrait evidence, refresh behavior, and cloud-safe brief redaction"
                    )
                }

                NavigationLink {
                    DebugAffectSnapshotView()
                } label: {
                    DebugMenuRow(
                        icon: "waveform.path.ecg.rectangle",
                        title: "Affect Snapshots",
                        subtitle: "Inspect structured mood, correction events, and Journaling Suggestions fallback state"
                    )
                }

                NavigationLink {
                    GraphDeltaReviewView()
                } label: {
                    DebugMenuRow(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "GraphDelta Review",
                        subtitle: "Product-path review for pending/applied graph deltas and apply actions"
                    )
                }

                NavigationLink {
                    ExternalCaptureDraftReviewView()
                } label: {
                    DebugMenuRow(
                        icon: "square.and.arrow.down.on.square",
                        title: "External Capture Recovery",
                        subtitle: "Debug failed App Intent, Share, and Journaling handoffs before importing them as memories"
                    )
                }

                NavigationLink {
                    PlatformCaptureDiagnosticsView()
                } label: {
                    DebugMenuRow(
                        icon: "checklist.checked",
                        title: "Platform Capture Diagnostics",
                        subtitle: "Inspect Journaling, Share Extension, App Intents, App Group, and device-validation readiness"
                    )
                }

                NavigationLink {
                    DebugHomeBoardDiagnosticsView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.grid.2x2",
                        title: "Home Board Debug",
                        subtitle: "Inspect memory desktop inputs, card layers, layout spans, reasons, and preference actions"
                    )
                }

                NavigationLink {
                    CaptureCardLabView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.stack",
                        title: "Capture Card Lab",
                        subtitle: "Preview capture attachment card styles, origins, states, and motion fixtures"
                    )
                }

                NavigationLink {
                    SkeuomorphicCardLabView()
                } label: {
                    DebugMenuRow(
                        icon: "rectangle.on.rectangle.angled",
                        title: "Skeuomorphic Card Lab",
                        subtitle: "Preview immersive card styles: Polaroid, Cassette, Notebook, Vinyl"
                    )
                }

                NavigationLink {
                    PlaceProfileManagementView(
                        memoryRepository: memoryRepository,
                        showsDebugDetails: true,
                        title: "Place Profiles Debug"
                    )
                } label: {
                    DebugMenuRow(
                        icon: "mappin.and.ellipse",
                        title: "Place Profiles",
                        subtitle: "Inspect, rename, merge, and split persistent place profiles"
                    )
                }

                NavigationLink {
                    DebugDataRepairView()
                } label: {
                    DebugMenuRow(
                        icon: "wrench.and.screwdriver",
                        title: "Data Repair",
                        subtitle: "Backfill missing captureOrigin metadata for legacy local artifacts"
                    )
                }

                NavigationLink {
                    NotificationManagementView()
                } label: {
                    DebugMenuRow(
                        icon: "bell.badge",
                        title: "Notification Management",
                        subtitle: "Inspect queue, history, dedupe, errors, preferences, and push diagnostics"
                    )
                }

                NavigationLink {
                    DebugFullDiagnosticsView(authManager: authManager)
                } label: {
                    DebugMenuRow(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: String(localized: "debug.menu.pipeline"),
                        subtitle: String(localized: "debug.menu.pipeline.subtitle")
                    )
                }

                NavigationLink {
                    DebugQualityTuningLabView()
                } label: {
                    DebugMenuRow(
                        icon: "slider.horizontal.3",
                        title: "Quality Tuning Lab",
                        subtitle: "Run real end-to-end tuning scenarios"
                    )
                }

                NavigationLink {
                    DebugCapabilityTestsView(
                        authManager: authManager,
                        runtimeEnvironment: runtimeEnvironment
                    )
                } label: {
                    DebugMenuRow(
                        icon: "testtube.2",
                        title: String(localized: "debug.menu.capabilities"),
                        subtitle: String(localized: "debug.menu.capabilities.subtitle")
                    )
                }
            } header: {
                Text("debug.title")
            } footer: {
                Text("debug.menu.footer")
            }
        }
        .navigationTitle("debug.title")
    }
}
private struct DebugLocalDataVaultView: View {
    @Environment(\.localDataDiagnostics) private var diagnostics

    var body: some View {
        List {
            Section {
                if let diagnostics {
                    LabeledContent("Owner", value: diagnostics.ownerID)
                    LabeledContent("Scope", value: diagnostics.scopeLabel)
                    LabeledContent("Store", value: diagnostics.storeURLDescription)
                    LabeledContent("Legacy owner", value: diagnostics.legacyOwnerID ?? "none")
                    LabeledContent("Legacy has user data", value: diagnostics.legacyStoreHasUserData ? "yes" : "no")
                } else {
                    Text("No active local data diagnostics.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Active vault")
            }

            if let diagnostics {
                Section {
                    ForEach(diagnostics.userDefaultsScopes) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.key)
                                    .font(.caption.monospaced())
                                Spacer()
                                Text(entry.scope.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(scopeColor(entry.scope))
                            }
                            Text(entry.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .textSelection(.enabled)
                    }
                } header: {
                    Text("UserDefaults scopes")
                } footer: {
                    Text("Device-scoped keys may persist across sign-out. Owner-scoped keys are namespaced by the active local data owner. Debug keys are development controls and do not store user memory content.")
                }
            }
        }
        .navigationTitle("Local Data Vault")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func scopeColor(_ scope: MoryUserDefaultsScopeKind) -> Color {
        switch scope {
        case .device:
            return .blue
        case .owner:
            return .green
        case .debug:
            return .orange
        }
    }
}

private struct DebugDataRepairView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var preview: ArtifactOriginRepairPreview?
    @State private var result: ArtifactOriginRepairResult?
    @State private var selectedOrigin: CaptureArtifactOrigin = .manual
    @State private var isRefreshing = false
    @State private var isRepairing = false
    @State private var errorMessage: String?
    @State private var isConfirmingRepair = false

    var body: some View {
        List {
            Section {
                Button {
                    refresh()
                } label: {
                    Label(isRefreshing ? "Refreshing" : "Refresh repair preview", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing || isRepairing)

                if isRefreshing {
                    DebugProgressRow(text: "Scanning artifacts")
                }

                if let preview {
                    DebugValueRow(title: "Total artifacts", value: "\(preview.totalArtifactCount)")
                    DebugValueRow(title: "Missing captureOrigin", value: "\(preview.missingOriginCount)")
                    DebugValueRow(title: "Generated", value: preview.generatedAt.formatted(date: .abbreviated, time: .standard))
                } else if !isRefreshing {
                    Text("No preview loaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Preview")
            } footer: {
                Text("This tool only updates artifacts that do not already have metadata.captureOrigin. Runtime readers do not infer fallback values.")
            }

            if let preview, !preview.kindCounts.isEmpty {
                Section("Missing by kind") {
                    ForEach(preview.kindCounts) { count in
                        DebugValueRow(title: count.kind.rawValue, value: "\(count.count)")
                    }
                }
            }

            Section {
                Picker("Backfill value", selection: $selectedOrigin) {
                    ForEach(CaptureArtifactOrigin.allCases, id: \.self) { origin in
                        Text(origin.captureBadgeLabel).tag(origin)
                    }
                }

                Button(role: .destructive) {
                    isConfirmingRepair = true
                } label: {
                    Label(isRepairing ? "Backfilling" : "Backfill missing origins", systemImage: "square.and.pencil")
                }
                .disabled(isRepairing || isRefreshing || (preview?.missingOriginCount ?? 0) == 0)

                if isRepairing {
                    DebugProgressRow(text: "Writing captureOrigin = \(selectedOrigin.rawValue)")
                }
            } header: {
                Text("Repair")
            } footer: {
                Text("Use Manual for user-added legacy artifacts, Context for auto-collected legacy context artifacts, Imported for imports, or Inferred for pipeline-generated content.")
            }

            if let result {
                Section("Last result") {
                    DebugValueRow(title: "Repaired", value: "\(result.repairedCount)")
                    DebugValueRow(title: "Origin", value: result.origin.rawValue)
                    DebugValueRow(title: "Generated", value: result.generatedAt.formatted(date: .abbreviated, time: .standard))
                    if !result.repairedArtifactIDs.isEmpty {
                        Text(result.repairedArtifactIDs.prefix(24).map(\.uuidString).joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }

            if let errorMessage {
                Section("Error") {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("Data Repair")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            refresh()
        }
        .refreshable {
            refresh()
        }
        .confirmationDialog(
            "Backfill missing captureOrigin?",
            isPresented: $isConfirmingRepair,
            titleVisibility: .visible
        ) {
            Button("Backfill as \(selectedOrigin.captureBadgeLabel)", role: .destructive) {
                repair()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This mutates local debug data. Existing captureOrigin values will not be overwritten.")
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        do {
            preview = try memoryRepository.fetchArtifactOriginRepairPreview()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRefreshing = false
    }

    private func repair() {
        guard !isRepairing else { return }
        isRepairing = true
        errorMessage = nil
        do {
            result = try memoryRepository.backfillMissingArtifactOrigins(selectedOrigin)
            preview = try memoryRepository.fetchArtifactOriginRepairPreview()
        } catch {
            errorMessage = error.localizedDescription
        }
        isRepairing = false
    }
}

private struct DebugEnvironmentView: View {
    let runtimeEnvironment: AppRuntimeEnvironment

    var body: some View {
        List {
            Section {
                environmentRow(String(localized: "debug.environment.buildChannel"), runtimeEnvironment.buildChannel.label)
                environmentRow(String(localized: "debug.environment.distribution"), runtimeEnvironment.distribution.rawValue)
                environmentRow(String(localized: "debug.environment.debugTools"), runtimeEnvironment.allowsDebugTools ? String(localized: "debug.value.enabled") : String(localized: "debug.value.disabled"))
                environmentRow(String(localized: "debug.environment.bundleID"), runtimeEnvironment.bundleIdentifier)
                environmentRow(String(localized: "debug.environment.version"), runtimeEnvironment.version)
                environmentRow(String(localized: "debug.environment.build"), runtimeEnvironment.buildNumber)
            } footer: {
                Text("debug.environment.footer")
            }
        }
        .navigationTitle("debug.menu.environment")
    }

    @ViewBuilder
    private func environmentRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

private struct DebugAuthSessionView: View {
    let authManager: AuthSessionManager?

    @State private var authDiagnostics: AuthDiagnosticsSnapshot?
    @State private var errorMessage: String?
    @State private var copiedToast: String?
    @State private var isSigningOut = false

    var body: some View {
        List {
            if let authDiagnostics {
                Section {
                    authRow(String(localized: "debug.auth.state"), authDiagnostics.state)
                    authRow(String(localized: "debug.auth.apiBaseURL"), authDiagnostics.apiBaseURL)
                    authRow(String(localized: "debug.auth.storedCredential"), yesNo(authDiagnostics.hasStoredCredential))
                    authRow(String(localized: "debug.auth.userID"), authDiagnostics.userID ?? String(localized: "debug.value.none"))
                    authRow(String(localized: "debug.auth.guest"), yesNo(authDiagnostics.isGuest))
                    authRow(String(localized: "debug.auth.accessToken"), presentMissing(authDiagnostics.hasAccessToken))
                    authRow(String(localized: "debug.auth.refreshToken"), presentMissing(authDiagnostics.hasRefreshToken))
                    authRow(String(localized: "debug.auth.appleIdentityToken"), presentMissing(authDiagnostics.hasIdentityToken))
                    authRow(String(localized: "debug.auth.expired"), yesNo(authDiagnostics.isExpired))
                    if let expiresAt = authDiagnostics.expiresAt {
                        authRow(String(localized: "debug.auth.expires"), expiresAt.formatted(date: .abbreviated, time: .standard))
                    }
                    if let lastEvent = authDiagnostics.lastEvent?.trimmedOrNil {
                        authRow(String(localized: "debug.auth.lastEvent"), lastEvent)
                    }
                    if let lastError = authDiagnostics.lastError?.trimmedOrNil {
                        errorRow(String(localized: "debug.auth.error"), lastError)
                    }
                    if let status = authDiagnostics.lastHTTPStatusCode {
                        authRow(String(localized: "debug.auth.lastHTTP"), "\(status)")
                    }
                    if let failedStage = authDiagnostics.lastFailedStage?.trimmedOrNil {
                        authRow(String(localized: "debug.auth.failedStage"), failedStage)
                    }
                    if let response = authDiagnostics.lastResponseBody?.trimmedOrNil {
                        payloadRow(title: String(localized: "debug.auth.responseBody"), content: response, recordID: nil)
                    }
                    Button {
                        let report = buildAuthReport(authDiagnostics)
                        UIPasteboard.general.string = report
                        showCopiedToast(String(localized: "debug.toast.authReportCopied"))
                    } label: {
                        Label("debug.auth.copyReport", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        Task { await signOut() }
                    } label: {
                        Label(isSigningOut ? String(localized: "debug.auth.signingOut") : String(localized: "debug.auth.signOut"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(isSigningOut)
                } header: {
                    Text("debug.menu.auth")
                } footer: {
                    Text("debug.auth.footer")
                }
            } else {
                Section {
                    Text("debug.auth.noManager")
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    errorRow(String(localized: "debug.auth.diagnosticsError"), errorMessage)
                }
            }
        }
        .navigationTitle("debug.menu.auth")
        .toolbar {
            Button {
                Task { await refresh() }
            } label: {
                Label("debug.action.refresh", systemImage: "arrow.clockwise")
            }
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
        .animation(.easeInOut(duration: 0.25), value: copiedToast)
        .task {
            await refresh()
        }
    }

    @MainActor
    private func refresh() async {
        authDiagnostics = await authManager?.fetchDiagnostics()
        errorMessage = authDiagnostics == nil ? String(localized: "debug.auth.managerUnavailable") : nil
    }

    @MainActor
    private func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }

        await authManager?.signOut()
        authDiagnostics = await authManager?.fetchDiagnostics()
        showCopiedToast(String(localized: "debug.toast.signedOut"))
    }

    @ViewBuilder
    private func authRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
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
                Text(verbatim: "\(content.count)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func copyButton(_ text: String, label: String) -> some View {
        Button {
            UIPasteboard.general.string = text
            showCopiedToast(String(format: String(localized: "debug.toast.copied"), label))
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .tint(.secondary)
    }

    private func payloadPreview(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "debug.payload.empty") }
        let firstLine = trimmed.prefix(120)
        return String(firstLine) + (trimmed.count > 120 ? "..." : "")
    }

    private func yesNo(_ value: Bool) -> String {
        String(localized: value ? "debug.value.yes" : "debug.value.no")
    }

    private func presentMissing(_ value: Bool) -> String {
        String(localized: value ? "debug.value.present" : "debug.value.missing")
    }

    private func buildAuthReport(_ auth: AuthDiagnosticsSnapshot) -> String {
        var lines: [String] = []
        lines.append("--- Mory Auth Debug Report ---")
        lines.append("Generated: \(Date.now.formatted(.iso8601))")
        lines.append("State: \(auth.state)")
        lines.append("API Base URL: \(auth.apiBaseURL)")
        lines.append("Stored Credential: \(auth.hasStoredCredential)")
        lines.append("User ID: \(auth.userID ?? String(localized: "debug.value.none"))")
        lines.append("Guest: \(auth.isGuest)")
        lines.append("Access Token Present: \(auth.hasAccessToken)")
        lines.append("Refresh Token Present: \(auth.hasRefreshToken)")
        lines.append("Apple Identity Token Present: \(auth.hasIdentityToken)")
        lines.append("Expired: \(auth.isExpired)")
        if let expiresAt = auth.expiresAt { lines.append("Expires: \(expiresAt.formatted(.iso8601))") }
        if let event = auth.lastEvent?.trimmedOrNil { lines.append("Last Event: \(event)") }
        if let error = auth.lastError?.trimmedOrNil { lines.append("Last Error: \(error)") }
        if let status = auth.lastHTTPStatusCode { lines.append("Last HTTP Status: \(status)") }
        if let stage = auth.lastFailedStage?.trimmedOrNil { lines.append("Failed Stage: \(stage)") }
        if let body = auth.lastResponseBody?.trimmedOrNil {
            lines.append("")
            lines.append("[Auth Response Body]")
            lines.append(prettyJSON(body))
        }
        return lines.joined(separator: "\n")
    }

    private func showCopiedToast(_ message: String) {
        copiedToast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            copiedToast = nil
        }
    }
}

struct DebugMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 3)
    }
}

struct DebugStorageIntegrityView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.memoryRepository) private var memoryRepository
    @State private var report: DebugStorageIntegrityReport?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isShowingClearAllConfirmation = false
    @State private var isClearingAllData = false

    var body: some View {
        List {
            Section {
                Button {
                    refreshReport()
                } label: {
                    Label("debug.storage.refresh", systemImage: "arrow.clockwise")
                }
            } footer: {
                Text("debug.storage.footer")
            }

            if let report {
                Section("debug.storage.counts") {
                    ForEach(report.counts) { count in
                        DebugValueRow(title: count.title, value: "\(count.value)")
                    }
                }

                Section("debug.storage.integrity") {
                    DebugCapabilityChecklistRow(
                        title: report.issueCount == 0 ? String(localized: "debug.storage.clean") : String(localized: "debug.storage.issues"),
                        detail: String(format: String(localized: "debug.storage.issueCount"), report.issueCount)
                    )
                    ForEach(report.issues) { issue in
                        DebugCapabilityChecklistRow(title: issue.title, detail: issue.detail)
                    }
                }
            }

            if let successMessage {
                Section {
                    Label(successMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }

            Section {
                Button(role: .destructive) {
                    isShowingClearAllConfirmation = true
                } label: {
                    Label(
                        isClearingAllData ? String(localized: "debug.storage.clearingAll") : String(localized: "debug.storage.clearAllData"),
                        systemImage: "trash.slash"
                    )
                }
                .disabled(isClearingAllData)
            } header: {
                Text("debug.storage.dangerZone")
            } footer: {
                Text("debug.storage.clearAllData.footer")
            }
        }
        .navigationTitle("debug.capability.storage")
        .confirmationDialog(
            "debug.storage.clearAllData.confirmTitle",
            isPresented: $isShowingClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("debug.storage.clearAllData.confirm", role: .destructive) {
                Task { await clearAllData() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("debug.storage.clearAllData.confirmMessage")
        }
        .task {
            refreshReport()
        }
    }

    @MainActor
    private func refreshReport() {
        do {
            report = try DebugStorageIntegrityReport.build(modelContext: modelContext)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func clearAllData() async {
        isClearingAllData = true
        defer { isClearingAllData = false }

        do {
            try memoryRepository.clearAllLocalData()
            successMessage = String(localized: "debug.storage.clearAllData.success")
            refreshReport()
        } catch {
            successMessage = nil
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import Photos
import AVFoundation
import Speech
import MusicKit

struct DebugDiagnosticsView: View {
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

private struct DebugMenuRow: View {
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

private struct DebugCapabilityTestsView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    var body: some View {
        List {
            Section {
                NavigationLink {
                    DebugPhotoTestView()
                } label: {
                    DebugMenuRow(
                        icon: "photo.on.rectangle",
                        title: String(localized: "debug.capability.photo"),
                        subtitle: String(localized: "debug.capability.photo.subtitle")
                    )
                }

                NavigationLink {
                    DebugContextServicesTestView()
                } label: {
                    DebugMenuRow(
                        icon: "cloud.sun",
                        title: String(localized: "debug.capability.context"),
                        subtitle: String(localized: "debug.capability.context.subtitle")
                    )
                }

                NavigationLink {
                    DebugSpeechTestView()
                } label: {
                    DebugMenuRow(
                        icon: "waveform.badge.mic",
                        title: String(localized: "debug.capability.speech"),
                        subtitle: String(localized: "debug.capability.speech.subtitle")
                    )
                }

                NavigationLink {
                    DebugLinkTestView()
                } label: {
                    DebugMenuRow(
                        icon: "link",
                        title: String(localized: "debug.capability.link"),
                        subtitle: String(localized: "debug.capability.link.subtitle")
                    )
                }

                NavigationLink {
                    DebugServerHealthView()
                } label: {
                    DebugMenuRow(
                        icon: "server.rack",
                        title: String(localized: "debug.capability.server"),
                        subtitle: String(localized: "debug.capability.server.subtitle")
                    )
                }

                NavigationLink {
                    DebugPermissionMatrixView()
                } label: {
                    DebugMenuRow(
                        icon: "checklist",
                        title: String(localized: "debug.capability.permissions"),
                        subtitle: String(localized: "debug.capability.permissions.subtitle")
                    )
                }

                NavigationLink {
                    DebugStorageIntegrityView()
                } label: {
                    DebugMenuRow(
                        icon: "externaldrive.badge.checkmark",
                        title: String(localized: "debug.capability.storage"),
                        subtitle: String(localized: "debug.capability.storage.subtitle")
                    )
                }

                NavigationLink {
                    DebugNotificationBackgroundView(
                        authManager: authManager,
                        runtimeEnvironment: runtimeEnvironment
                    )
                } label: {
                    DebugMenuRow(
                        icon: "bell.badge",
                        title: String(localized: "debug.capability.notification"),
                        subtitle: String(localized: "debug.capability.notification.subtitle")
                    )
                }
            } footer: {
                Text("debug.capability.footer")
            }

            Section {
                DebugCapabilityChecklistRow(title: String(localized: "debug.capability.extra.auth"), detail: String(localized: "debug.capability.extra.auth.detail"))
                DebugCapabilityChecklistRow(title: String(localized: "debug.capability.extra.api"), detail: String(localized: "debug.capability.extra.api.detail"))
                DebugCapabilityChecklistRow(title: String(localized: "debug.capability.extra.pipeline"), detail: String(localized: "debug.capability.extra.pipeline.detail"))
                DebugCapabilityChecklistRow(title: String(localized: "debug.capability.extra.permissions"), detail: String(localized: "debug.capability.extra.permissions.detail"))
            } header: {
                Text("debug.capability.extra")
            }
        }
        .navigationTitle("debug.menu.capabilities")
    }
}

private struct DebugPhotoTestView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var photoFilename = ""
    @State private var result: PhotoArtifactProcessor.Result?
    @State private var isProcessingLocal = false
    @State private var isRunningCloud = false
    @State private var cloudMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("debug.photo.select", systemImage: "photo")
                }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    Task { await loadAndProcessPhoto(newItem) }
                }

                if let selectedPhotoData, let image = UIImage(data: selectedPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if isProcessingLocal {
                    DebugProgressRow(text: String(localized: "debug.photo.processingLocal"))
                }
            } footer: {
                Text("debug.photo.footer")
            }

            if let result {
                Section("debug.photo.localResult") {
                    DebugValueRow(title: String(localized: "debug.result.title"), value: result.title)
                    DebugValueRow(title: String(localized: "debug.result.summary"), value: result.summary.nonEmptyDisplay)
                    DebugValueRow(title: String(localized: "debug.photo.ocr"), value: result.ocrText.nonEmptyDisplay)
                    DebugValueRow(title: String(localized: "debug.photo.thumbnailBytes"), value: "\(result.thumbnailData.count)")
                    DebugValueRow(title: String(localized: "debug.photo.metadata"), value: result.metadata.isEmpty ? String(localized: "debug.value.none") : result.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))

                    Button {
                        Task { await runCloudPipeline(result) }
                    } label: {
                        Label(isRunningCloud ? String(localized: "debug.photo.runningCloud") : String(localized: "debug.photo.runCloud"), systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(isRunningCloud)
                }
            }

            if let cloudMessage {
                Section("debug.photo.cloudResult") {
                    Text(cloudMessage)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("debug.capability.photo")
    }

    @MainActor
    private func loadAndProcessPhoto(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
        selectedPhotoData = data
        photoFilename = "debug_photo_\(Int(Date().timeIntervalSince1970)).jpg"
        result = nil
        cloudMessage = nil
        errorMessage = nil
        isProcessingLocal = true
        defer { isProcessingLocal = false }

        result = await PhotoArtifactProcessor().process(imageData: data, filename: photoFilename)
    }

    @MainActor
    private func runCloudPipeline(_ result: PhotoArtifactProcessor.Result) async {
        guard let selectedPhotoData else { return }
        isRunningCloud = true
        cloudMessage = nil
        errorMessage = nil
        defer { isRunningCloud = false }

        do {
            let summaryText = [result.summary.trimmedOrNil, result.ocrText.trimmedOrNil]
                .compactMap { $0 }
                .joined(separator: "\n")
            let memory = try await memoryRepository.createMemory(
                from: MemoryCaptureDraft(
                    title: "Debug photo test",
                    rawText: summaryText.trimmedOrNil ?? "Debug photo test",
                    inputContext: "Debug photo local + cloud analysis test",
                    artifacts: [
                        .photo(
                            title: result.title,
                            summary: result.summary,
                            filename: photoFilename,
                            imageData: selectedPhotoData,
                            thumbnailData: result.thumbnailData,
                            ocrText: result.ocrText,
                            photoMetadata: result.metadata
                        )
                    ]
                )
            )
            cloudMessage = [
                "recordID: \(memory.record.id.uuidString)",
                "title: \(memory.title)",
                "summary: \(memory.summaryText)",
                "pipeline: \(memory.pipelineStatus?.userLabel ?? String(localized: "debug.value.none"))"
            ].joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DebugContextServicesTestView: View {
    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())
    @State private var drafts: [CaptureArtifactDraft] = []
    @State private var isCollecting = false
    @State private var message: String?

    var body: some View {
        List {
            Section("debug.context.permissions") {
                DebugValueRow(title: String(localized: "debug.context.location"), value: permissionLabel(permissionManager.locationStatus))
                DebugValueRow(title: String(localized: "debug.context.music"), value: permissionLabel(permissionManager.musicStatus))

                Button {
                    Task {
                        await permissionManager.requestLocationIfNeeded()
                        permissionManager.refresh()
                    }
                } label: {
                    Label("debug.context.requestLocation", systemImage: "location")
                }

                Button {
                    Task {
                        await permissionManager.requestMusicIfNeeded()
                        permissionManager.refresh()
                    }
                } label: {
                    Label("debug.context.requestMusic", systemImage: "music.note")
                }
            }

            Section {
                Button {
                    Task { await collectContext() }
                } label: {
                    Label(isCollecting ? String(localized: "debug.context.collecting") : String(localized: "debug.context.collect"), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isCollecting)
            } footer: {
                Text("debug.context.footer")
            }

            if !drafts.isEmpty {
                Section("debug.context.results") {
                    ForEach(Array(drafts.enumerated()), id: \.offset) { _, draft in
                        DebugCapabilityChecklistRow(title: draft.debugKindLabel, detail: draft.captureSummary)
                    }
                }
            }

            if let message {
                Section {
                    Text(message)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("debug.capability.context")
        .task {
            permissionManager.refresh()
        }
    }

    @MainActor
    private func collectContext() async {
        isCollecting = true
        drafts = []
        message = nil
        defer { isCollecting = false }

        drafts = await ContextAutoCollector().collectContextDrafts()
        message = drafts.isEmpty ? String(localized: "debug.context.empty") : String(format: String(localized: "debug.context.count"), drafts.count)
        permissionManager.refresh()
    }

    private func permissionLabel(_ status: ContextPermissionManager.Status) -> String {
        switch status {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .authorized: String(localized: "debug.value.authorized")
        }
    }
}

private struct DebugSpeechTestView: View {
    @State private var isImporterPresented = false
    @State private var selectedFilename: String?
    @State private var isTranscribing = false
    @State private var result: AudioTranscriptionService.Result?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    isImporterPresented = true
                } label: {
                    Label("debug.speech.selectAudio", systemImage: "waveform")
                }

                if let selectedFilename {
                    DebugValueRow(title: String(localized: "debug.speech.file"), value: selectedFilename)
                }

                if isTranscribing {
                    DebugProgressRow(text: String(localized: "debug.speech.transcribing"))
                }
            } footer: {
                Text("debug.speech.footer")
            }

            if let result {
                Section("debug.speech.result") {
                    DebugValueRow(title: String(localized: "debug.speech.locale"), value: result.locale.identifier)
                    DebugValueRow(title: String(localized: "debug.speech.duration"), value: result.duration.formatted(.number.precision(.fractionLength(2))))
                    DebugValueRow(title: String(localized: "debug.speech.text"), value: result.transcription)
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("debug.capability.speech")
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.audio], allowsMultipleSelection: false) { importResult in
            Task { await handleImport(importResult) }
        }
    }

    @MainActor
    private func handleImport(_ importResult: Result<[URL], Error>) async {
        do {
            guard let url = try importResult.get().first else { return }
            selectedFilename = url.lastPathComponent
            result = nil
            errorMessage = nil
            isTranscribing = true
            defer { isTranscribing = false }

            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            if let transcription = await AudioTranscriptionService().transcribe(audioData: data, filename: url.lastPathComponent) {
                result = transcription
            } else {
                errorMessage = String(localized: "debug.speech.noResult")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DebugLinkTestView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var urlString = "https://apple.com"
    @State private var metadata: LinkMetadataResult?
    @State private var isFetching = false
    @State private var isRunningCloud = false
    @State private var cloudMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                TextField("debug.link.url", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await fetchMetadata() }
                } label: {
                    Label(isFetching ? String(localized: "debug.link.fetching") : String(localized: "debug.link.fetch"), systemImage: "link.badge.plus")
                }
                .disabled(isFetching)

                if isFetching {
                    DebugProgressRow(text: String(localized: "debug.link.fetching"))
                }
            } footer: {
                Text("debug.link.footer")
            }

            if let metadata {
                Section("debug.link.result") {
                    DebugValueRow(title: String(localized: "debug.link.normalizedURL"), value: metadata.url)
                    DebugValueRow(title: String(localized: "debug.result.title"), value: metadata.title.nonEmptyDisplay)
                    DebugValueRow(title: String(localized: "debug.result.summary"), value: metadata.summary.nonEmptyDisplay)
                    DebugValueRow(title: String(localized: "debug.link.site"), value: metadata.siteName.nonEmptyDisplay)
                    DebugValueRow(title: String(localized: "debug.link.imageBytes"), value: "\(metadata.imageData?.count ?? 0)")

                    Button {
                        Task { await runCloudPipeline(metadata) }
                    } label: {
                        Label(isRunningCloud ? String(localized: "debug.link.runningCloud") : String(localized: "debug.link.runCloud"), systemImage: "icloud.and.arrow.up")
                    }
                    .disabled(isRunningCloud)
                }
            }

            if let cloudMessage {
                Section("debug.link.cloudResult") {
                    Text(cloudMessage)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Section {
                    DebugErrorMessageRow(message: errorMessage)
                }
            }
        }
        .navigationTitle("debug.capability.link")
    }

    @MainActor
    private func fetchMetadata() async {
        isFetching = true
        metadata = nil
        cloudMessage = nil
        errorMessage = nil
        defer { isFetching = false }

        metadata = await LinkMetadataExtractor().extract(urlString: urlString)
        if metadata == nil {
            errorMessage = String(localized: "debug.link.noResult")
        }
    }

    @MainActor
    private func runCloudPipeline(_ metadata: LinkMetadataResult) async {
        isRunningCloud = true
        cloudMessage = nil
        errorMessage = nil
        defer { isRunningCloud = false }

        do {
            let memory = try await memoryRepository.createMemory(
                from: MemoryCaptureDraft(
                    title: metadata.title ?? "Debug link test",
                    rawText: [metadata.title, metadata.summary, metadata.url].compactMap { $0?.trimmedOrNil }.joined(separator: "\n"),
                    inputContext: "Debug link metadata + cloud analysis test",
                    artifacts: [
                        .link(
                            title: metadata.title,
                            url: metadata.url,
                            note: nil,
                            summary: metadata.summary,
                            metadata: metadata.metadata,
                            thumbnailData: metadata.imageData
                        )
                    ]
                )
            )
            cloudMessage = [
                "recordID: \(memory.record.id.uuidString)",
                "title: \(memory.title)",
                "summary: \(memory.summaryText)",
                "pipeline: \(memory.pipelineStatus?.userLabel ?? String(localized: "debug.value.none"))"
            ].joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DebugServerHealthView: View {
    @State private var probes: [DebugEndpointProbe] = []
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                DebugValueRow(title: String(localized: "debug.server.baseURL"), value: MoryAPIConfiguration.fromBundle().baseURL.absoluteString)
                Button {
                    Task { await runProbes() }
                } label: {
                    Label(isRunning ? String(localized: "debug.server.running") : String(localized: "debug.server.run"), systemImage: "network")
                }
                .disabled(isRunning)
                if isRunning {
                    DebugProgressRow(text: String(localized: "debug.server.running"))
                }
            } footer: {
                Text("debug.server.footer")
            }

            if !probes.isEmpty {
                Section("debug.server.results") {
                    ForEach(probes) { probe in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: probe.isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(probe.isReachable ? .green : .orange)
                                Text(probe.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(verbatim: probe.latencyText)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Text(verbatim: probe.detail)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
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
        .navigationTitle("debug.capability.server")
    }

    @MainActor
    private func runProbes() async {
        isRunning = true
        probes = []
        errorMessage = nil
        defer { isRunning = false }

        let configuration = MoryAPIConfiguration.fromBundle()
        do {
            probes = await [
                probe(name: String(localized: "debug.server.probe.root"), request: URLRequest(url: configuration.baseURL)),
                probe(name: String(localized: "debug.server.probe.health"), request: URLRequest(url: configuration.url(for: "/healthz"))),
                probe(name: String(localized: "debug.server.probe.auth"), request: jsonPost(url: configuration.url(for: "/auth/apple"), body: ["identity_token": "debug-invalid-token"])),
                probe(name: String(localized: "debug.server.probe.analysis"), request: jsonPost(url: configuration.url(for: "/api/analysis/records"), body: [:]))
            ]
        }
    }

    private func jsonPost(url: URL, body: [String: String]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    private func probe(name: String, request: URLRequest) async -> DebugEndpointProbe {
        let startedAt = Date()
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let latency = Date().timeIntervalSince(startedAt)
            guard let http = response as? HTTPURLResponse else {
                return DebugEndpointProbe(name: name, statusCode: nil, latency: latency, error: String(localized: "debug.server.nonHTTP"))
            }
            return DebugEndpointProbe(name: name, statusCode: http.statusCode, latency: latency, error: nil)
        } catch {
            return DebugEndpointProbe(name: name, statusCode: nil, latency: Date().timeIntervalSince(startedAt), error: error.localizedDescription)
        }
    }
}

private struct DebugPermissionMatrixView: View {
    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())
    @State private var rows: [DebugPermissionRow] = []
    @State private var isTestingWeather = false
    @State private var weatherStatus = String(localized: "debug.permission.weather.notTested")

    var body: some View {
        List {
            Section {
                Button {
                    refreshRows()
                } label: {
                    Label("debug.permission.refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await requestPhotos() }
                } label: {
                    Label("debug.permission.request.photos", systemImage: "photo")
                }

                Button {
                    Task { await requestMicrophone() }
                } label: {
                    Label("debug.permission.request.microphone", systemImage: "mic")
                }

                Button {
                    Task { await requestSpeech() }
                } label: {
                    Label("debug.permission.request.speech", systemImage: "waveform")
                }

                Button {
                    Task {
                        await permissionManager.requestLocationIfNeeded()
                        refreshRows()
                    }
                } label: {
                    Label("debug.permission.request.location", systemImage: "location")
                }

                Button {
                    Task {
                        await permissionManager.requestMusicIfNeeded()
                        refreshRows()
                    }
                } label: {
                    Label("debug.permission.request.music", systemImage: "music.note")
                }

                Button {
                    Task { await testWeatherKit() }
                } label: {
                    Label(isTestingWeather ? String(localized: "debug.permission.weather.testing") : String(localized: "debug.permission.weather.test"), systemImage: "cloud.sun")
                }
                .disabled(isTestingWeather)
            } footer: {
                Text("debug.permission.footer")
            }

            Section("debug.permission.matrix") {
                ForEach(rows) { row in
                    DebugCapabilityChecklistRow(title: row.title, detail: row.detail)
                }
                DebugCapabilityChecklistRow(title: String(localized: "debug.permission.weather"), detail: weatherStatus)
            }
        }
        .navigationTitle("debug.capability.permissions")
        .task {
            refreshRows()
        }
    }

    @MainActor
    private func refreshRows() {
        permissionManager.refresh()
        rows = [
            DebugPermissionRow(title: String(localized: "debug.permission.photos"), detail: photosStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.microphone"), detail: microphoneStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.speech"), detail: speechStatusText()),
            DebugPermissionRow(title: String(localized: "debug.permission.location"), detail: permissionLabel(permissionManager.locationStatus)),
            DebugPermissionRow(title: String(localized: "debug.permission.music"), detail: permissionLabel(permissionManager.musicStatus))
        ]
    }

    @MainActor
    private func requestPhotos() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        refreshRows()
    }

    @MainActor
    private func requestMicrophone() async {
        _ = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        refreshRows()
    }

    @MainActor
    private func requestSpeech() async {
        _ = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        refreshRows()
    }

    @MainActor
    private func testWeatherKit() async {
        isTestingWeather = true
        weatherStatus = String(localized: "debug.permission.weather.testing")
        defer { isTestingWeather = false }

        let locationService = LocationContextService()
        guard locationService.isAuthorized else {
            weatherStatus = String(localized: "debug.permission.weather.locationRequired")
            return
        }
        guard let location = await locationService.currentLocation() else {
            weatherStatus = String(localized: "debug.permission.weather.noLocation")
            return
        }
        if let draft = await WeatherContextService().captureCurrentWeather(location: location) {
            weatherStatus = draft.captureSummary
        } else {
            weatherStatus = String(localized: "debug.permission.weather.failed")
        }
    }

    private func photosStatusText() -> String {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .restricted: String(localized: "debug.value.restricted")
        case .denied: String(localized: "debug.value.denied")
        case .authorized: String(localized: "debug.value.authorized")
        case .limited: String(localized: "debug.value.limited")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func microphoneStatusText() -> String {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .granted: String(localized: "debug.value.authorized")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func speechStatusText() -> String {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .restricted: String(localized: "debug.value.restricted")
        case .authorized: String(localized: "debug.value.authorized")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private func permissionLabel(_ status: ContextPermissionManager.Status) -> String {
        switch status {
        case .notDetermined: String(localized: "debug.value.notDetermined")
        case .denied: String(localized: "debug.value.denied")
        case .authorized: String(localized: "debug.value.authorized")
        }
    }
}

private struct DebugStorageIntegrityView: View {
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

private struct DebugNotificationBackgroundView: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @Environment(\.scenePhase) private var scenePhase
    @State private var authDiagnostics: AuthDiagnosticsSnapshot?
    @State private var lastNotificationText = String(localized: "debug.notification.none")
    @State private var checkSessionMessage: String?

    var body: some View {
        List {
            Section {
                DebugValueRow(title: String(localized: "debug.environment.buildChannel"), value: runtimeEnvironment.buildChannel.label)
                DebugValueRow(title: String(localized: "debug.environment.distribution"), value: runtimeEnvironment.distribution.rawValue)
                DebugValueRow(title: String(localized: "debug.notification.scenePhase"), value: scenePhaseText)
                DebugValueRow(title: String(localized: "debug.notification.receipt"), value: receiptText)
                DebugValueRow(title: String(localized: "debug.notification.debugTools"), value: runtimeEnvironment.allowsDebugTools ? String(localized: "debug.value.enabled") : String(localized: "debug.value.disabled"))
            } header: {
                Text("debug.notification.runtime")
            }

            Section {
                DebugValueRow(title: String(localized: "debug.notification.lastPipeline"), value: lastNotificationText)
                Button {
                    postTestNotification()
                } label: {
                    Label("debug.notification.postTest", systemImage: "bell")
                }
            } header: {
                Text("debug.notification.pipeline")
            } footer: {
                Text("debug.notification.footer")
            }

            Section {
                if let authDiagnostics {
                    DebugValueRow(title: String(localized: "debug.auth.state"), value: authDiagnostics.state)
                    DebugValueRow(title: String(localized: "debug.auth.storedCredential"), value: authDiagnostics.hasStoredCredential ? String(localized: "debug.value.yes") : String(localized: "debug.value.no"))
                    DebugValueRow(title: String(localized: "debug.auth.expired"), value: authDiagnostics.isExpired ? String(localized: "debug.value.yes") : String(localized: "debug.value.no"))
                }
                if let checkSessionMessage {
                    Text(checkSessionMessage)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                Button {
                    Task { await runSessionRestoreCheck() }
                } label: {
                    Label("debug.notification.checkSession", systemImage: "key")
                }
            } header: {
                Text("debug.notification.coldStart")
            } footer: {
                Text("debug.notification.coldStart.footer")
            }
        }
        .navigationTitle("debug.capability.notification")
        .onReceive(NotificationCenter.default.publisher(for: .pipelineDidComplete)) { notification in
            let recordID = (notification.userInfo?["recordID"] as? UUID)?.uuidString ?? String(localized: "debug.value.none")
            lastNotificationText = "\(Date.now.formatted(date: .omitted, time: .standard)) \(recordID)"
        }
        .task {
            authDiagnostics = await authManager?.fetchDiagnostics()
        }
    }

    private var scenePhaseText: String {
        switch scenePhase {
        case .active: String(localized: "debug.notification.scene.active")
        case .inactive: String(localized: "debug.notification.scene.inactive")
        case .background: String(localized: "debug.notification.scene.background")
        @unknown default: String(localized: "debug.value.unknown")
        }
    }

    private var receiptText: String {
        String(format: String(localized: "debug.notification.receipt.detected"), runtimeEnvironment.distribution.rawValue)
    }

    private func postTestNotification() {
        NotificationCenter.default.post(
            name: .pipelineDidComplete,
            object: nil,
            userInfo: ["recordID": UUID()]
        )
    }

    @MainActor
    private func runSessionRestoreCheck() async {
        await authManager?.checkSession()
        authDiagnostics = await authManager?.fetchDiagnostics()
        checkSessionMessage = String(localized: "debug.notification.checkSession.done")
    }
}

private struct DebugValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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

private struct DebugProgressRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DebugErrorMessageRow: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(.orange)
                .textSelection(.enabled)
        }
    }
}

private struct DebugCapabilityChecklistRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct DebugEndpointProbe: Identifiable {
    let id = UUID()
    let name: String
    let statusCode: Int?
    let latency: TimeInterval
    let error: String?

    var isReachable: Bool {
        statusCode != nil
    }

    var latencyText: String {
        String(format: "%.0f ms", latency * 1000)
    }

    var detail: String {
        if let statusCode {
            return "HTTP \(statusCode)"
        }
        return error ?? String(localized: "debug.value.unknown")
    }
}

private struct DebugQualityGateRow: Identifiable {
    let id = UUID()
    let title: String
    let passed: Bool
    let result: String
    let detail: String
}

private struct DebugPermissionRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct DebugStorageCount: Identifiable {
    let id = UUID()
    let title: String
    let value: Int
}

private struct DebugStorageIssue: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct DebugStorageIntegrityReport {
    let counts: [DebugStorageCount]
    let issues: [DebugStorageIssue]

    var issueCount: Int {
        issues.reduce(0) { total, issue in
            let firstNumber = issue.detail.split(separator: " ").first.flatMap { Int($0) }
            return total + (firstNumber ?? 1)
        }
    }

    @MainActor
    static func build(modelContext: ModelContext) throws -> DebugStorageIntegrityReport {
        let records = try modelContext.fetch(FetchDescriptor<RecordShellStore>())
        let artifacts = try modelContext.fetch(FetchDescriptor<ArtifactStore>())
        let analyses = try modelContext.fetch(FetchDescriptor<RecordAnalysisSnapshotStore>())
        let entities = try modelContext.fetch(FetchDescriptor<EntityNodeStore>())
        let edges = try modelContext.fetch(FetchDescriptor<EntityEdgeStore>())
        let links = try modelContext.fetch(FetchDescriptor<ArtifactEntityLinkStore>())
        let arcs = try modelContext.fetch(FetchDescriptor<TemporalArcStore>())
        let reflections = try modelContext.fetch(FetchDescriptor<ReflectionSnapshotStore>())
        let pipelines = try modelContext.fetch(FetchDescriptor<MemoryPipelineStatusStore>())

        let recordIDs = Set(records.map(\.id))
        let artifactIDs = Set(artifacts.map(\.id))
        let entityIDs = Set(entities.map(\.id))
        let arcIDs = Set(arcs.map(\.id))

        var issues: [DebugStorageIssue] = []
        appendIssue(&issues, title: String(localized: "debug.storage.orphanArtifacts"), missingCount: artifacts.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.missingRecordArtifacts"), missingCount: records.flatMap(\.artifactIDs).filter { !artifactIDs.contains($0) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.orphanAnalyses"), missingCount: analyses.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.orphanPipelines"), missingCount: pipelines.filter { !recordIDs.contains($0.recordID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenLinks"), missingCount: links.filter { !artifactIDs.contains($0.artifactID) || !entityIDs.contains($0.entityID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenEdges"), missingCount: edges.filter { !entityIDs.contains($0.fromEntityID) || !entityIDs.contains($0.toEntityID) }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenArcs"), missingCount: arcs.filter {
            !$0.sourceRecordIDs.allSatisfy(recordIDs.contains)
                || !$0.sourceArtifactIDs.allSatisfy(artifactIDs.contains)
                || !$0.sourceEntityIDs.allSatisfy(entityIDs.contains)
        }.count)
        appendIssue(&issues, title: String(localized: "debug.storage.brokenReflections"), missingCount: reflections.filter {
            !$0.sourceRecordIDs.allSatisfy(recordIDs.contains)
                || !$0.sourceArtifactIDs.allSatisfy(artifactIDs.contains)
                || !$0.sourceEntityIDs.allSatisfy(entityIDs.contains)
                || ($0.linkedTemporalArcID.map { !arcIDs.contains($0) } ?? false)
        }.count)

        return DebugStorageIntegrityReport(
            counts: [
                DebugStorageCount(title: String(localized: "debug.storage.records"), value: records.count),
                DebugStorageCount(title: String(localized: "debug.storage.artifacts"), value: artifacts.count),
                DebugStorageCount(title: String(localized: "debug.storage.analyses"), value: analyses.count),
                DebugStorageCount(title: String(localized: "debug.storage.entities"), value: entities.count),
                DebugStorageCount(title: String(localized: "debug.storage.edges"), value: edges.count),
                DebugStorageCount(title: String(localized: "debug.storage.links"), value: links.count),
                DebugStorageCount(title: String(localized: "debug.storage.arcs"), value: arcs.count),
                DebugStorageCount(title: String(localized: "debug.storage.reflections"), value: reflections.count),
                DebugStorageCount(title: String(localized: "debug.storage.pipelines"), value: pipelines.count)
            ],
            issues: issues
        )
    }

    private static func appendIssue(_ issues: inout [DebugStorageIssue], title: String, missingCount: Int) {
        guard missingCount > 0 else { return }
        issues.append(DebugStorageIssue(title: title, detail: String(format: String(localized: "debug.storage.issueDetail"), missingCount)))
    }
}

private struct DebugQualityTuningLabView: View {
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

private struct DebugQualityTuningReportView: View {
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

private struct DebugQualityTuningReportBody: View {
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

private struct DebugFullDiagnosticsView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    let authManager: AuthSessionManager?

    @State private var targetType: DebugAnalysisTarget = .memory
    @State private var selectedTargetID: UUID?
    @State private var targetSummary: String = "Latest memory"
    @State private var authDiagnostics: AuthDiagnosticsSnapshot?
    @State private var diagnostics: DebugDiagnosticsSnapshot?
    @State private var recentTargets: [DebugTargetRow] = []
    @State private var pipelineStatuses: [PipelineStatusSummary] = []
    @State private var errorMessage: String?
    @State private var isSeeding = false
    @State private var isRebuilding = false
    @State private var isReloading = false
    @State private var copiedToast: String?
    @State private var actionLog: [DebugActionLogEntry] = []
    @State private var customTitle = ""
    @State private var customBody = ""
    @State private var customMood = ""
    @State private var customContext = ""
    @State private var customIncludeAutoContext = true
    @State private var customContextDrafts: [CaptureArtifactDraft] = []
    @State private var isCreatingCustomMemory = false

    var body: some View {
        List {
            // MARK: - Auth Session

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
                            .font(.caption)
                    }
                } header: {
                    Text("debug.menu.auth")
                } footer: {
                    Text("debug.auth.footer")
                }
            }

            // MARK: - Custom Diagnostic Memory

            Section {
                TextField("debug.custom.title", text: $customTitle)
                TextField("debug.custom.body", text: $customBody, axis: .vertical)
                    .lineLimit(3...8)
                TextField("debug.custom.mood", text: $customMood)
                TextField("debug.custom.context", text: $customContext, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("debug.custom.includeContext", isOn: $customIncludeAutoContext)

                if !customContextDrafts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("debug.custom.contextAdded")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(customContextDrafts.indices, id: \.self) { index in
                            Label(customContextDrafts[index].captureSummary, systemImage: customContextDrafts[index].debugIconName)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }

                Button {
                    Task { await createCustomDiagnosticMemory() }
                } label: {
                    Label(isCreatingCustomMemory ? String(localized: "debug.custom.creating") : String(localized: "debug.custom.create"), systemImage: "plus.square.on.square")
                }
                .disabled(isCreatingCustomMemory || (customTitle.trimmedOrNil == nil && customBody.trimmedOrNil == nil))
            } header: {
                Text("debug.section.customDiagnostic")
            } footer: {
                Text("debug.custom.footer")
            }

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
                        showCopiedToast(String(format: String(localized: "debug.toast.fullReportCopied"), report.count))
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
                    Text(String(format: String(localized: "debug.actionLog.count"), actionLog.count))
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

                Section {
                    ForEach(qualityGateRows(for: diagnostics)) { row in
                        DebugChainRow(
                            title: row.title,
                            isComplete: row.passed,
                            detail: row.result,
                            subdetail: row.detail
                        )
                    }
                } header: {
                    Text("debug.section.qualityGates")
                } footer: {
                    Text("debug.quality.footer")
                }

                Section {
                    if let fixture = diagnostics.fixture {
                        let contextArtifacts = contextArtifacts(from: fixture.chain)
                        if contextArtifacts.isEmpty {
                            Text("debug.context.empty")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(contextArtifacts) { artifact in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Label(artifact.kind.rawValue, systemImage: contextIconName(for: artifact.kind))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        copyButton(artifact.id.uuidString, label: "ID")
                                    }
                                    Text(artifact.title)
                                        .font(.subheadline.weight(.medium))
                                    Text(artifact.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !artifact.metadata.isEmpty {
                                        Text(artifact.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "\n"))
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.tertiary)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } else {
                        Text("debug.chain.noFixture")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("debug.section.contextArtifacts")
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
                                Text(String(format: String(localized: "debug.pipeline.failedStage"), failedStage))
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
                            showCopiedToast(String(localized: "debug.toast.pipelineTraceCopied"))
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
                    Text(verbatim: "\(String(localized: "debug.section.provenance")) (\(diagnostics.provenance.count))")
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
                    Text(verbatim: "\(String(localized: "debug.section.allPipelines")) (\(pipelineStatuses.count))")
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
            showCopiedToast(String(format: String(localized: "debug.toast.payloadsCopied"), label, text.count))
        } label: {
            Label(String(format: String(localized: "debug.payload.copyAll"), label), systemImage: "doc.on.doc")
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
            showCopiedToast(String(format: String(localized: "debug.toast.copied"), label))
        } label: {
            Image(systemName: "doc.on.clipboard")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .tint(.secondary)
    }

    @ViewBuilder
    private func badge(_ label: String, count: Int) -> some View {
        Text(verbatim: "\(count) \(label)")
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
            authDiagnostics = await authManager?.fetchDiagnostics()
            recentTargets = try fetchRecentTargets(for: targetType)
            pipelineStatuses = try memoryRepository.fetchPipelineStatusSummaries(limit: 12)
            errorMessage = nil
        } catch {
            authDiagnostics = await authManager?.fetchDiagnostics()
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

    private func createCustomDiagnosticMemory() async {
        guard !isCreatingCustomMemory else { return }
        let body = customBody.trimmedOrNil ?? customTitle.trimmedOrNil
        guard let body else { return }

        isCreatingCustomMemory = true
        defer { isCreatingCustomMemory = false }

        appendLog("Creating custom diagnostic memory...")
        do {
            let contextDrafts = customIncludeAutoContext ? await ContextAutoCollector().collectContextDrafts() : []
            customContextDrafts = contextDrafts
            let inputContext = [
                "debug fixture seed",
                customContext.trimmedOrNil
            ]
            .compactMap { $0 }
            .joined(separator: "\n")

            let draft = MemoryCaptureDraft(
                title: customTitle.trimmedOrNil,
                rawText: body,
                mood: customMood.trimmedOrNil,
                inputContext: inputContext,
                captureSource: .composer,
                artifacts: [.text(title: customTitle.trimmedOrNil, body: body)] + contextDrafts
            )
            let memory = try await memoryRepository.createMemory(from: draft)
            try await memoryRepository.refreshMemoryPipeline(recordID: memory.record.id)
            targetType = .memory
            selectedTargetID = memory.record.id
            appendLog("Custom diagnostic memory created: \(memory.record.id.uuidString)")
            await refreshDiagnostics()
        } catch {
            appendLog("Custom diagnostic memory failed: \(error.localizedDescription)", isError: true)
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

    private func contextArtifacts(from chain: DebugMemoryChainSnapshot) -> [Artifact] {
        chain.artifacts.filter {
            $0.kind == .location || $0.kind == .weather || $0.kind == .music
        }
    }

    private func qualityGateRows(for diagnostics: DebugDiagnosticsSnapshot) -> [DebugQualityGateRow] {
        guard let fixture = diagnostics.fixture else {
            return [
                DebugQualityGateRow(
                    title: String(localized: "debug.quality.noTarget"),
                    passed: false,
                    result: String(localized: "debug.value.missing"),
                    detail: String(localized: "debug.chain.noFixture")
                )
            ]
        }

        let entityPolicy = EntityQualityPolicy()
        let reflectionPolicy = ReflectionQualityPolicy()
        var rows: [DebugQualityGateRow] = []

        if let rawEntities = rawAnalyzeEntities(from: diagnostics.analyzePayload?.responseBody), !rawEntities.isEmpty {
            for entity in rawEntities {
                let result = entityPolicy.evaluate(entity)
                rows.append(
                    DebugQualityGateRow(
                        title: "\(String(localized: "debug.quality.entity")) · \(entity.kind.rawValue): \(entity.name)",
                        passed: result.passed,
                        result: result.passed ? String(localized: "debug.value.accepted") : String(localized: "debug.value.filtered"),
                        detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
                    )
                )
            }
        } else if let analysis = fixture.chain.analysis {
            for entity in analysis.entityMentions {
                let result = entityPolicy.evaluate(entity)
                rows.append(
                    DebugQualityGateRow(
                        title: "\(String(localized: "debug.quality.entity")) · \(entity.kind.rawValue): \(entity.name)",
                        passed: result.passed,
                        result: result.passed ? String(localized: "debug.value.accepted") : String(localized: "debug.value.filtered"),
                        detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
                    )
                )
            }
        }

        if fixture.chain.arcs.isEmpty {
            rows.append(
                DebugQualityGateRow(
                    title: String(localized: "debug.quality.arc"),
                    passed: false,
                    result: String(localized: "debug.value.filtered"),
                    detail: String(localized: "debug.quality.arc.filtered")
                )
            )
        } else {
            for arc in fixture.chain.arcs {
                rows.append(
                    DebugQualityGateRow(
                        title: "\(String(localized: "debug.quality.arc")) · \(arc.title)",
                        passed: true,
                        result: String(localized: "debug.value.accepted"),
                        detail: "records \(Set(arc.sourceRecordIDs).count) · cluster \(arc.clusterStrength)"
                    )
                )
            }
        }

        if let analysis = fixture.chain.analysis {
            let result = reflectionPolicy.shouldRequestRecordReflection(
                record: fixture.chain.record,
                artifacts: fixture.chain.artifacts,
                analysis: analysis
            )
            rows.append(
                DebugQualityGateRow(
                    title: String(localized: "debug.quality.recordReflection"),
                    passed: result.passed,
                    result: result.passed ? String(localized: "debug.value.accepted") : String(localized: "debug.value.filtered"),
                    detail: [result.reason, result.metric].compactMap(\.self).joined(separator: " · ")
                )
            )
        }

        if rows.isEmpty {
            rows.append(
                DebugQualityGateRow(
                    title: String(localized: "debug.section.qualityGates"),
                    passed: false,
                    result: String(localized: "debug.value.missing"),
                    detail: String(localized: "debug.quality.empty")
                )
            )
        }
        return rows
    }

    private func rawAnalyzeEntities(from responseBody: String?) -> [EntityReference]? {
        guard
            let data = responseBody?.data(using: .utf8),
            let envelope = try? JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: data)
        else {
            return nil
        }
        return envelope.entities.compactMap { entity in
            guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
            return EntityReference(
                kind: kind,
                name: entity.name,
                aliases: entity.aliases ?? [],
                confidence: entity.confidence
            )
        }
    }

    private func contextIconName(for kind: ArtifactKind) -> String {
        switch kind {
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .music: return "music.note"
        default: return "shippingbox"
        }
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

    private func yesNo(_ value: Bool) -> String {
        String(localized: value ? "debug.value.yes" : "debug.value.no")
    }

    private func presentMissing(_ value: Bool) -> String {
        String(localized: value ? "debug.value.present" : "debug.value.missing")
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

    private func buildAuthReport(_ auth: AuthDiagnosticsSnapshot) -> String {
        var lines: [String] = []
        lines.append("--- Mory Auth Debug Report ---")
        lines.append("Generated: \(Date.now.formatted(.iso8601))")
        lines.append("State: \(auth.state)")
        lines.append("API Base URL: \(auth.apiBaseURL)")
        lines.append("Stored Credential: \(auth.hasStoredCredential)")
        lines.append("User ID: \(auth.userID ?? "none")")
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
            let contextArtifacts = contextArtifacts(from: fixture.chain)
            lines.append("Context:    \(contextArtifacts.count)")
            for a in contextArtifacts {
                lines.append("  [\(a.kind.rawValue)] \(a.title) — \(a.summary.prefix(80))")
                if !a.metadata.isEmpty {
                    lines.append("    \(a.metadata.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", "))")
                }
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
        if let id = trace.requestID?.trimmedOrNil { lines.append("Request ID: \(id)") }
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
                Text(verbatim: "\(displayContent.count) chars")
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

private extension String {
    var nonEmptyDisplay: String {
        trimmedOrNil ?? String(localized: "debug.value.none")
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyDisplay: String {
        self?.trimmedOrNil ?? String(localized: "debug.value.none")
    }
}

private extension CaptureArtifactDraft {
    var debugKindLabel: String {
        switch self {
        case .text: String(localized: "capture.type.text")
        case .photo: String(localized: "capture.type.photo")
        case .audio: String(localized: "capture.type.audio")
        case .location: String(localized: "capture.type.location")
        case .link: String(localized: "capture.type.link")
        case .todo: String(localized: "capture.type.todo")
        case .weather: String(localized: "capture.type.weather")
        case .music: String(localized: "capture.type.music")
        }
    }

    var debugIconName: String {
        switch self {
        case .text: "text.alignleft"
        case .photo: "photo"
        case .audio: "waveform"
        case .location: "mappin.and.ellipse"
        case .link: "link"
        case .todo: "checklist"
        case .weather: "cloud.sun"
        case .music: "music.note"
        }
    }
}

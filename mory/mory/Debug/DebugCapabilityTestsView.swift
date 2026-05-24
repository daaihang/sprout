import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers
import Photos
import AVFoundation
import Speech
import MusicKit

struct DebugCapabilityTestsView: View {
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

struct DebugPhotoTestView: View {
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

struct DebugContextServicesTestView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())
    @State private var drafts: [CaptureArtifactDraft] = []
    @State private var diagnostics: [ContextCollectionDiagnostic] = []
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

            if !diagnostics.isEmpty {
                Section("Diagnostics") {
                    ForEach(diagnostics) { diagnostic in
                        DebugCapabilityChecklistRow(
                            title: "\(diagnostic.component.rawValue): \(diagnostic.status.rawValue)",
                            detail: "\(diagnostic.elapsedMilliseconds)ms · \(diagnostic.message)"
                        )
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
        diagnostics = []
        defer { isCollecting = false }

        let policy = (try? memoryRepository.fetchUserSettingsPreference().defaultContextSelection) ?? .allAvailable
        let result = await ContextAutoCollector().collectContext(policy: policy)
        drafts = result.drafts
        diagnostics = result.diagnostics
        message = drafts.isEmpty
            ? "\(String(localized: "debug.context.empty")) · \(result.elapsedMilliseconds)ms"
            : "\(String(format: String(localized: "debug.context.count"), drafts.count)) · \(result.elapsedMilliseconds)ms"
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

struct DebugSpeechTestView: View {
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

struct DebugLinkTestView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    @State private var urlString = "https://apple.com"
    @State private var bodyText = "Saved this post for later: https://apple.com"
    @State private var detectedURL: String?
    @State private var metadata: LinkMetadataResult?
    @State private var detectedMetadata: LinkMetadataResult?
    @State private var isFetching = false
    @State private var isDetecting = false
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
                    DebugValueRow(title: String(localized: "debug.link.inputURL"), value: urlString)
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

            Section {
                TextField("debug.link.bodyInput", text: $bodyText, axis: .vertical)
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.sentences)

                Button {
                    Task { await detectBodyLink() }
                } label: {
                    Label(isDetecting ? String(localized: "debug.link.detecting") : String(localized: "debug.link.detectBody"), systemImage: "text.magnifyingglass")
                }
                .disabled(isDetecting)

                if isDetecting {
                    DebugProgressRow(text: String(localized: "debug.link.detecting"))
                }
            } header: {
                Text("debug.link.autoDetect")
            } footer: {
                Text("debug.link.autoDetectFooter")
            }

            if let detectedURL {
                Section("debug.link.autoDetectResult") {
                    DebugValueRow(title: String(localized: "debug.link.detectedURL"), value: detectedURL)
                    if let detectedMetadata {
                        DebugValueRow(title: String(localized: "debug.link.normalizedURL"), value: detectedMetadata.url)
                        DebugValueRow(title: String(localized: "debug.result.title"), value: detectedMetadata.title.nonEmptyDisplay)
                        DebugValueRow(title: String(localized: "debug.result.summary"), value: detectedMetadata.summary.nonEmptyDisplay)
                        DebugValueRow(title: String(localized: "debug.link.site"), value: detectedMetadata.siteName.nonEmptyDisplay)
                        DebugValueRow(title: String(localized: "debug.link.imageBytes"), value: "\(detectedMetadata.imageData?.count ?? 0)")
                    }
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
    private func detectBodyLink() async {
        isDetecting = true
        detectedURL = nil
        detectedMetadata = nil
        cloudMessage = nil
        errorMessage = nil
        defer { isDetecting = false }

        guard let candidate = LinkMetadataExtractor.firstURLCandidate(in: bodyText) else {
            errorMessage = String(localized: "debug.link.noDetectedURL")
            return
        }

        detectedURL = candidate
        detectedMetadata = await LinkMetadataExtractor().extract(urlString: candidate)
        if detectedMetadata == nil {
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


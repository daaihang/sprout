import SwiftUI
import PhotosUI
import Combine

struct CaptureComposerView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: CaptureInputType
    @State private var title = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var inputContext = ""
    @State private var attachmentValue = ""
    @State private var secondaryValue = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedStatusMessage: String?
    @State private var stagedArtifactDrafts: [CaptureArtifactDraft] = []
    @State private var contextCandidates: [ContextCandidate] = []
    @State private var isCollectingContext = false
    @State private var hasLoadedInitialContext = false

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoThumbnail: Data?
    @State private var photoFilename = ""
    @State private var isProcessingPhoto = false
    @State private var photoProcessorResult: PhotoArtifactProcessor.Result?
    @State private var audioRecorder = AudioRecorderModel()
    @State private var transcriptionText = ""
    @State private var transcriptionDuration: TimeInterval?
    @State private var linkMetadata: LinkMetadataResult?
    @State private var isFetchingLinkPreview = false
    @State private var autoDetectedLinkMetadata: LinkMetadataResult?
    @State private var autoDetectedLinkURL: String?
    @State private var isFetchingAutoLinkPreview = false
    @State private var selectedLocationDraft: CaptureArtifactDraft?
    @State private var isPresentingLocationPicker = false

    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())

    var onSaved: (() -> Void)?

    init(startsWithPhoto: Bool = false, onSaved: (() -> Void)? = nil) {
        _selectedType = State(initialValue: startsWithPhoto ? .photo : .text)
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("capture.localFirst.hint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("capture.section.capture") {
                    Picker("capture.picker.type", selection: $selectedType) {
                        ForEach(CaptureInputType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    TextField("capture.field.title", text: $title)
                        .onChange(of: title) { _, _ in
                            Task { await refreshAutoDetectedLinkPreview() }
                        }

                    switch selectedType {
                    case .photo:
                        PhotoInputView(
                            selectedPhotoItem: $selectedPhotoItem,
                            selectedPhotoData: $selectedPhotoData,
                            selectedPhotoThumbnail: $selectedPhotoThumbnail,
                            photoFilename: $photoFilename,
                            isProcessingPhoto: $isProcessingPhoto,
                            photoProcessorResult: $photoProcessorResult,
                            noteText: $bodyText
                        )

                    case .audio:
                        AudioCaptureInputView(
                            audioRecorder: audioRecorder,
                            transcriptionText: $transcriptionText,
                            transcriptionDuration: $transcriptionDuration,
                            noteText: $bodyText
                        )

                    case .link:
                        LinkInputView(
                            urlText: $attachmentValue,
                            noteText: $bodyText,
                            metadata: linkMetadata,
                            isFetching: isFetchingLinkPreview
                        ) { value in
                            Task { await fetchLinkPreview(urlString: value) }
                        }

                    case .location:
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                isPresentingLocationPicker = true
                            } label: {
                                Label(
                                    selectedLocationDraft == nil ? String(localized: "capture.location.pick") : String(localized: "capture.location.change"),
                                    systemImage: "map"
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            if let selectedLocationDraft {
                                HStack(alignment: .top, spacing: 8) {
                                    Label(selectedLocationDraft.captureSummary, systemImage: selectedLocationDraft.captureIconName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                    Spacer()
                                    Button(role: .destructive) {
                                        self.selectedLocationDraft = nil
                                    } label: {
                                        Image(systemName: "xmark.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            } else {
                                Text("capture.location.pickHint")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TextField("capture.prompt.location", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    default:
                        TextField(selectedType.primaryPrompt, text: $bodyText, axis: .vertical)
                            .lineLimit(selectedType == .text ? 4...10 : 2...5)
                            .onChange(of: bodyText) { _, _ in
                                Task { await refreshAutoDetectedLinkPreview() }
                            }
                    }

                    if let attachmentPrompt = selectedType.attachmentPrompt, selectedType != .photo && selectedType != .audio && selectedType != .link && selectedType != .location {
                        TextField(attachmentPrompt, text: $attachmentValue)
                    }
                    if let secondaryPrompt = selectedType.secondaryPrompt, selectedType != .audio && selectedType != .location {
                        TextField(secondaryPrompt, text: $secondaryValue)
                    }

                    if selectedType != .link {
                        AutoDetectedLinkPreview(
                            metadata: autoDetectedLinkMetadata,
                            isFetching: isFetchingAutoLinkPreview
                        )
                    }

                    CurrentArtifactPreview(drafts: currentArtifactDrafts)

                    HStack {
                        Button {
                            addCurrentContent()
                        } label: {
                            Label("capture.action.addContent", systemImage: "plus.circle")
                        }
                        .disabled(currentArtifactDrafts.isEmpty)

                        Button(role: .destructive) {
                            clearCurrentInput()
                        } label: {
                            Label("capture.action.clearCurrent", systemImage: "xmark.circle")
                        }
                        .disabled(currentArtifactDrafts.isEmpty && bodyText.isEmpty && attachmentValue.isEmpty && secondaryValue.isEmpty)
                    }
                }

                ArtifactStagingListView(drafts: $stagedArtifactDrafts)

                Section("capture.section.context") {
                    TextField("capture.field.mood", text: $mood)
                    TextField("capture.field.context", text: $inputContext, axis: .vertical)
                        .lineLimit(2...4)
                }

                if permissionManager.anyMissing {
                    Section {
                        Text("capture.context.autoCollectHint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if permissionManager.locationStatus != .authorized {
                            Button {
                                Task {
                                    await permissionManager.requestLocationIfNeeded()
                                    await refreshAutoContext()
                                }
                            } label: {
                                Label(
                                    permissionManager.locationStatus == .denied
                                        ? String(localized: "capture.context.locationOpenSettings")
                                        : String(localized: "capture.context.enableLocation"),
                                    systemImage: "mappin.and.ellipse"
                                )
                            }
                            .disabled(permissionManager.locationStatus == .denied)
                        }
                        if permissionManager.musicStatus != .authorized {
                            Button {
                                Task {
                                    await permissionManager.requestMusicIfNeeded()
                                    await refreshAutoContext()
                                }
                            } label: {
                                Label(
                                    permissionManager.musicStatus == .denied
                                        ? String(localized: "capture.context.musicOpenSettings")
                                        : String(localized: "capture.context.enableMusic"),
                                    systemImage: "music.note"
                                )
                            }
                            .disabled(permissionManager.musicStatus == .denied)
                        }
                    } header: {
                        Text("capture.section.contextAuto")
                    }
                }

                ContextCandidateListView(
                    candidates: $contextCandidates,
                    isCollecting: isCollectingContext
                ) {
                    Task { await refreshAutoContext() }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                if let savedStatusMessage {
                    Section {
                        Text(savedStatusMessage)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("capture.nav.title")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                permissionManager.refresh()
                Task { await loadInitialAutoContextIfNeeded() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
            .sheet(isPresented: $isPresentingLocationPicker) {
                LocationPickerView(initialSelection: selectedLocationDraft) { draft in
                    selectedLocationDraft = draft
                }
            }
        }
    }

    private var normalizedTitle: String? {
        title.trimmedOrNil ?? bodyText.firstMeaningfulLine
    }

    private var normalizedCaptureText: String? {
        bodyText.trimmedOrNil ?? title.trimmedOrNil ?? transcriptionText.trimmedOrNil
    }

    private var canSave: Bool {
        !isProcessingPhoto && !audioRecorder.isBusy && !userArtifactDrafts.isEmpty
    }

    private var currentArtifactDrafts: [CaptureArtifactDraft] {
        switch selectedType {
        case .text:
            guard let rawText = normalizedCaptureText else { return [] }
            return [.text(title: normalizedTitle, body: rawText)]
        case .photo:
            let userNote = bodyText.trimmedOrNil ?? title.trimmedOrNil
            let processorSummary = photoProcessorResult?.summary.trimmedOrNil
            let summary = userNote ?? processorSummary ?? "Photo capture"
            guard let filename = photoFilename.trimmedOrNil else { return [] }
            let resolvedTitle = normalizedTitle ?? photoProcessorResult?.title.trimmedOrNil
            return [.photo(
                title: resolvedTitle,
                summary: summary,
                filename: filename,
                imageData: selectedPhotoData,
                thumbnailData: selectedPhotoThumbnail,
                ocrText: photoProcessorResult?.ocrText ?? "",
                photoMetadata: photoProcessorResult?.metadata ?? [:]
            )]
        case .audio:
            let summary = bodyText.trimmedOrNil ?? title.trimmedOrNil ?? "Audio capture"
            guard let filename = audioRecorder.recordedFilename else { return [] }
            return [.audio(
                title: normalizedTitle,
                summary: summary,
                filename: filename,
                audioData: audioRecorder.recordedAudioData,
                transcriptionText: transcriptionText
            )]
        case .location:
            guard let selectedLocationDraft else { return [] }
            guard case let .location(placeTitle, placeSummary, latitude, longitude, _) = selectedLocationDraft else { return [] }
            return [.location(
                title: normalizedTitle ?? placeTitle,
                summary: bodyText.trimmedOrNil ?? placeSummary,
                latitude: latitude,
                longitude: longitude
            )]
        case .link:
            guard let url = attachmentValue.trimmedOrNil else { return [] }
            return [.link(
                title: normalizedTitle ?? linkMetadata?.title,
                url: linkMetadata?.url ?? url,
                note: bodyText.trimmedOrNil,
                summary: linkMetadata?.summary,
                metadata: linkMetadata?.metadata ?? ["url": url],
                thumbnailData: linkMetadata?.imageData
            )]
        case .todo:
            guard let title = normalizedTitle ?? bodyText.trimmedOrNil else { return [] }
            return [.todo(title: title, note: secondaryValue.trimmedOrNil ?? bodyText.trimmedOrNil)]
        }
    }

    private var userArtifactDrafts: [CaptureArtifactDraft] {
        stagedArtifactDrafts + currentArtifactDrafts + autoDetectedLinkDrafts
    }

    private var autoDetectedLinkDrafts: [CaptureArtifactDraft] {
        guard selectedType != .link, let metadata = autoDetectedLinkMetadata else { return [] }
        let detectedURL = metadata.url.trimmedOrNil
        let existingURLs = (stagedArtifactDrafts + currentArtifactDrafts).compactMap { draft -> String? in
            guard case let .link(_, url, _, _, _, _, _) = draft else { return nil }
            return url.trimmedOrNil
        }
        guard let detectedURL, !existingURLs.contains(detectedURL) else { return [] }

        return [.link(
            title: metadata.title,
            url: detectedURL,
            note: selectedType == .text ? bodyText.trimmedOrNil : nil,
            summary: metadata.summary,
            metadata: metadata.metadata,
            thumbnailData: metadata.imageData
        )]
    }

    private var selectedContextDrafts: [CaptureArtifactDraft] {
        contextCandidates
            .filter(\.isSelected)
            .map(\.draft)
    }

    private var allArtifactDrafts: [CaptureArtifactDraft] {
        userArtifactDrafts + selectedContextDrafts
    }

    private var resolvedCaptureSource: CaptureSource {
        guard stagedArtifactDrafts.isEmpty, currentArtifactDrafts.count == 1 else {
            return .composer
        }
        return selectedType.captureSource
    }

    private func save() async {
        guard !isSaving, canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let drafts = allArtifactDrafts
            let rawText = normalizedCaptureText
                ?? drafts.map(\.captureSummary).joined(separator: "\n").trimmedOrNil
                ?? title.trimmedOrNil
                ?? "Untitled Memory"

            let draft = MemoryCaptureDraft(
                title: normalizedTitle,
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                captureSource: resolvedCaptureSource,
                artifacts: drafts
            )

            let orchestrator = CaptureOrchestrator(memoryRepository: memoryRepository)
            let memory = try await orchestrator.capture(draft: draft)
            savedStatusMessage = memory.pipelineStatus?.userLabel ?? String(localized: "pipeline.status.pending")
            errorMessage = nil
            onSaved?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            savedStatusMessage = nil
        }
    }

    private func addCurrentContent() {
        let drafts = currentArtifactDrafts
        guard !drafts.isEmpty else { return }
        stagedArtifactDrafts.append(contentsOf: drafts)
        clearCurrentInput()
    }

    private func clearCurrentInput() {
        bodyText = ""
        attachmentValue = ""
        secondaryValue = ""
        selectedPhotoItem = nil
        selectedPhotoData = nil
        selectedPhotoThumbnail = nil
        photoFilename = ""
        photoProcessorResult = nil
        linkMetadata = nil
        autoDetectedLinkMetadata = nil
        autoDetectedLinkURL = nil
        selectedLocationDraft = nil
        transcriptionText = ""
        transcriptionDuration = nil
        audioRecorder.clearRecording()
    }

    private func loadInitialAutoContextIfNeeded() async {
        guard !hasLoadedInitialContext else { return }
        hasLoadedInitialContext = true
        await refreshAutoContext()
    }

    private func refreshAutoContext() async {
        guard !isCollectingContext else { return }
        isCollectingContext = true
        defer { isCollectingContext = false }
        let collectedAt = Date.now
        let drafts = await ContextAutoCollector().collectContextDrafts()
        contextCandidates = drafts.map { draft in
            ContextCandidate(
                draft: draft,
                capturedAt: collectedAt,
                isSelected: true
            )
        }
    }

    private func fetchLinkPreview(urlString: String) async {
        guard urlString.trimmedOrNil != nil else {
            linkMetadata = nil
            isFetchingLinkPreview = false
            return
        }

        isFetchingLinkPreview = true
        defer { isFetchingLinkPreview = false }

        let extractor = LinkMetadataExtractor()
        linkMetadata = await extractor.extract(urlString: urlString)
    }

    private func refreshAutoDetectedLinkPreview() async {
        guard selectedType != .link else { return }
        let candidate = firstURLCandidate(in: [title, bodyText].joined(separator: "\n"))
        guard candidate != autoDetectedLinkURL else { return }
        autoDetectedLinkURL = candidate

        guard let candidate else {
            autoDetectedLinkMetadata = nil
            isFetchingAutoLinkPreview = false
            return
        }

        isFetchingAutoLinkPreview = true
        try? await Task.sleep(for: .milliseconds(350))
        guard candidate == autoDetectedLinkURL else {
            isFetchingAutoLinkPreview = false
            return
        }

        autoDetectedLinkMetadata = await LinkMetadataExtractor().extract(urlString: candidate)
        isFetchingAutoLinkPreview = false
    }

    private func firstURLCandidate(in text: String) -> String? {
        LinkMetadataExtractor.firstURLCandidate(in: text)
    }

}

private enum CaptureInputType: String, CaseIterable, Identifiable {
    case text
    case photo
    case audio
    case location
    case link
    case todo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return String(localized: "capture.type.text")
        case .photo: return String(localized: "capture.type.photo")
        case .audio: return String(localized: "capture.type.audio")
        case .location: return String(localized: "capture.type.location")
        case .link: return String(localized: "capture.type.link")
        case .todo: return String(localized: "capture.type.todo")
        }
    }

    var primaryPrompt: String {
        switch self {
        case .text: return String(localized: "capture.prompt.text")
        case .photo: return String(localized: "capture.prompt.photo")
        case .audio: return String(localized: "capture.prompt.audio")
        case .location: return String(localized: "capture.prompt.location")
        case .link: return String(localized: "capture.prompt.link")
        case .todo: return String(localized: "capture.prompt.todo")
        }
    }

    var attachmentPrompt: String? {
        switch self {
        case .photo: return String(localized: "capture.attachment.filename")
        case .audio: return String(localized: "capture.attachment.filename")
        case .location: return String(localized: "capture.attachment.latitude")
        case .link: return String(localized: "capture.attachment.url")
        case .text, .todo: return nil
        }
    }

    var secondaryPrompt: String? {
        switch self {
        case .location: return String(localized: "capture.secondary.longitude")
        case .todo: return String(localized: "capture.secondary.note")
        case .text, .photo, .audio, .link: return nil
        }
    }

    var captureSource: CaptureSource {
        switch self {
        case .text, .link, .todo, .location:
            return .composer
        case .photo:
            return .photo
        case .audio:
            return .audio
        }
    }
}

import SwiftUI
import PhotosUI
import AVFoundation
import Combine

struct CaptureComposerView: View {
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: CaptureInputType = .text
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
    @State private var isTranscribing = false
    @State private var transcriptionText = ""
    @State private var transcriptionDuration: TimeInterval?
    @State private var linkMetadata: LinkMetadataResult?
    @State private var isFetchingLinkPreview = false

    @StateObject private var permissionManager = ContextPermissionManager(locationService: LocationContextService())

    var onSaved: (() -> Void)?

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

                    switch selectedType {
                    case .photo:
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let selectedPhotoData {
                                if let uiImage = UIImage(data: selectedPhotoData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(8)
                                }
                                Text("capture.photo.selected").foregroundStyle(.secondary)
                            } else {
                                Label("capture.photo.select", systemImage: "photo")
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    selectedPhotoData = data
                                    let filename = "photo_\(Date().timeIntervalSince1970).jpg"
                                    photoFilename = filename
                                    isProcessingPhoto = true
                                    photoProcessorResult = nil
                                    let processor = PhotoArtifactProcessor()
                                    let result = await processor.process(imageData: data, filename: filename)
                                    selectedPhotoThumbnail = result.thumbnailData
                                    photoProcessorResult = result
                                    isProcessingPhoto = false
                                }
                            }
                        }
                        if isProcessingPhoto {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("capture.photo.analyzing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let result = photoProcessorResult {
                            VStack(alignment: .leading, spacing: 4) {
                                if !result.summary.isEmpty {
                                    Text(result.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                                if !result.ocrText.isEmpty {
                                    Text("capture.photo.ocrPreview \(String(result.ocrText.prefix(100)))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        TextField("capture.photo.notePlaceholder", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    case .audio:
                        VStack(spacing: 12) {
                            if audioRecorder.isRecording {
                                HStack {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 12, height: 12)
                                        .opacity(audioRecorder.recordingDuration > 0 ? 1 : 0.5)
                                    Text("capture.audio.recording \(Int(audioRecorder.recordingDuration))")
                                        .font(.headline)
                                    Spacer()
                                    Button(String(localized: "capture.audio.stop")) {
                                        audioRecorder.toggleRecording()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                }
                            } else {
                                Button {
                                    transcriptionText = ""
                                    transcriptionDuration = nil
                                    audioRecorder.toggleRecording()
                                } label: {
                                    Label(
                                        audioRecorder.recordedAudioURL != nil ? String(localized: "capture.audio.rerecord") : String(localized: "capture.audio.startRecording"),
                                        systemImage: "mic.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            if let url = audioRecorder.recordedAudioURL {
                                HStack {
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.secondary)
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onChange(of: audioRecorder.isRecording) { wasRecording, isNowRecording in
                            if wasRecording && !isNowRecording {
                                Task { await transcribeAudio() }
                            }
                        }
                        if isTranscribing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("capture.audio.transcribing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !transcriptionText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("capture.audio.transcription")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("capture.audio.editTranscription", text: $transcriptionText, axis: .vertical)
                                    .lineLimit(3...8)
                                    .font(.subheadline)
                                if let duration = transcriptionDuration {
                                    Text("capture.audio.transcriptionTime \(String(format: "%.1f", duration))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        TextField("capture.audio.notePlaceholder", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    case .link:
                        TextField("capture.attachment.url", text: $attachmentValue)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .onChange(of: attachmentValue) { _, newValue in
                                Task { await fetchLinkPreview(urlString: newValue) }
                            }
                        if isFetchingLinkPreview {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("capture.link.fetching")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let meta = linkMetadata {
                            VStack(alignment: .leading, spacing: 4) {
                                if let imageData = meta.imageData,
                                   let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                if let title = meta.title {
                                    Text(title)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                }
                                if let summary = meta.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if let site = meta.siteName {
                                    Text(site)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        TextField("capture.prompt.link", text: $bodyText, axis: .vertical)
                            .lineLimit(2...5)

                    default:
                        TextField(selectedType.primaryPrompt, text: $bodyText, axis: .vertical)
                            .lineLimit(selectedType == .text ? 4...10 : 2...5)
                    }

                    if let attachmentPrompt = selectedType.attachmentPrompt, selectedType != .photo && selectedType != .audio && selectedType != .link {
                        TextField(attachmentPrompt, text: $attachmentValue)
                    }
                    if let secondaryPrompt = selectedType.secondaryPrompt, selectedType != .audio {
                        TextField(secondaryPrompt, text: $secondaryValue)
                    }

                    if !currentArtifactDrafts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("capture.content.current")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(currentArtifactDrafts.indices, id: \.self) { index in
                                Label(currentArtifactDrafts[index].captureSummary, systemImage: currentArtifactDrafts[index].debugIconName)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                    }

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

                Section {
                    if stagedArtifactDrafts.isEmpty {
                        Text("capture.content.empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(stagedArtifactDrafts.indices, id: \.self) { index in
                            HStack(alignment: .top) {
                                Label(stagedArtifactDrafts[index].captureSummary, systemImage: stagedArtifactDrafts[index].debugIconName)
                                    .font(.subheadline)
                                    .lineLimit(3)
                                Spacer()
                                Button(role: .destructive) {
                                    stagedArtifactDrafts.remove(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                } header: {
                    Text("capture.section.addedContent")
                } footer: {
                    Text("capture.content.footer")
                }

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

                Section {
                    Button {
                        Task { await refreshAutoContext() }
                    } label: {
                        Label(isCollectingContext ? String(localized: "capture.context.collecting") : String(localized: "capture.context.collectPreview"), systemImage: "arrow.clockwise")
                    }
                    .disabled(isCollectingContext)

                    if isCollectingContext {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("capture.context.collecting")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if contextCandidates.isEmpty {
                        Text("capture.context.previewEmpty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contextCandidates) { candidate in
                            Toggle(isOn: contextSelectionBinding(for: candidate.id)) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(candidate.draft.captureSummary, systemImage: candidate.draft.debugIconName)
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text(candidate.capturedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("capture.section.contextPreview")
                } footer: {
                    Text("capture.context.previewFooter")
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
        }
    }

    private var normalizedTitle: String? {
        title.trimmedOrNil ?? bodyText.firstMeaningfulLine
    }

    private var normalizedCaptureText: String? {
        bodyText.trimmedOrNil ?? title.trimmedOrNil ?? transcriptionText.trimmedOrNil
    }

    private var canSave: Bool {
        !isProcessingPhoto && !isTranscribing && !userArtifactDrafts.isEmpty
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
            guard bodyText.trimmedOrNil != nil || title.trimmedOrNil != nil || attachmentValue.trimmedOrNil != nil || secondaryValue.trimmedOrNil != nil else {
                return []
            }
            let latitude = Double(attachmentValue.trimmingCharacters(in: .whitespacesAndNewlines))
            let longitude = Double(secondaryValue.trimmingCharacters(in: .whitespacesAndNewlines))
            return [.location(title: normalizedTitle, summary: bodyText.trimmedOrNil ?? title.trimmedOrNil ?? "Location capture", latitude: latitude, longitude: longitude)]
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
        stagedArtifactDrafts + currentArtifactDrafts
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

    private func contextSelectionBinding(for id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                contextCandidates.first(where: { $0.id == id })?.isSelected ?? false
            },
            set: { isSelected in
                guard let index = contextCandidates.firstIndex(where: { $0.id == id }) else { return }
                contextCandidates[index].isSelected = isSelected
            }
        )
    }

    private func transcribeAudio() async {
        guard let audioData = audioRecorder.recordedAudioData else { return }
        isTranscribing = true
        defer { isTranscribing = false }

        let service = AudioTranscriptionService()
        if let result = await service.transcribe(audioData: audioData, filename: audioRecorder.recordedFilename) {
            transcriptionText = result.transcription
            transcriptionDuration = result.duration
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
}

private struct ContextCandidate: Identifiable, Hashable {
    let id = UUID()
    var draft: CaptureArtifactDraft
    var capturedAt: Date
    var isSelected: Bool
}

private extension CaptureArtifactDraft {
    var debugIconName: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .location: return "mappin.and.ellipse"
        case .link: return "link"
        case .todo: return "checklist"
        case .weather: return "cloud.sun"
        case .music: return "music.note"
        }
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

@MainActor
final class AudioRecorderModel: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private let audioSession = AVAudioSession()

    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordedAudioURL: URL?
    @Published var recordedAudioData: Data?

    var recordedFilename: String? {
        recordedAudioURL?.lastPathComponent
    }

    init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        let filename = "audio_\(Date().timeIntervalSince1970).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordingDuration = 0

            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated {
                    self.recordingDuration += 0.1
                }
            }
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false

        if let url = audioRecorder?.url {
            recordedAudioURL = url
            recordedAudioData = try? Data(contentsOf: url)
        }
    }

    func clearRecording() {
        if isRecording {
            stopRecording()
        }
        recordedAudioURL = nil
        recordedAudioData = nil
        recordingDuration = 0
    }
}

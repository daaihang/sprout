import PhotosUI
import SwiftUI
import UIKit

struct UnifiedCaptureSeed: Identifiable, Equatable {
    let id = UUID()
    var voiceResult: QuickVoiceCaptureResult?
    var opensCameraOnAppear = false

    static var empty: UnifiedCaptureSeed {
        UnifiedCaptureSeed()
    }

    static var photoCapture: UnifiedCaptureSeed {
        UnifiedCaptureSeed(opensCameraOnAppear: true)
    }

    static func voice(_ result: QuickVoiceCaptureResult) -> UnifiedCaptureSeed {
        UnifiedCaptureSeed(voiceResult: result)
    }
}

struct UnifiedCaptureComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.memoryRepository) private var memoryRepository
    @Environment(\.cloudIntelligenceService) private var cloudIntelligenceService

    let seed: UnifiedCaptureSeed
    let onSaved: () -> Void

    @State private var generatedTitle = ""
    @State private var bodyText = ""
    @State private var mood = ""
    @State private var inputContext = ""
    @State private var stagedArtifactDrafts: [CaptureArtifactDraft] = []
    @State private var contextCandidates: [ContextCandidate] = []
    @State private var isCollectingContext = false
    @State private var hasLoadedInitialContext = false

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isPresentingCamera = false
    @State private var isPresentingAudioCapture = false
    @State private var isPresentingLinkCapture = false
    @State private var isPresentingMusicCapture = false
    @State private var isPresentingLocationPicker = false
    @State private var isPresentingTodoCapture = false

    @State private var isProcessingPhoto = false
    @State private var isRefiningVoiceTranscript = false
    @State private var didAttemptVoiceRefinement = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isBodyFocused: Bool

    private var selectedContextDrafts: [CaptureArtifactDraft] {
        contextCandidates.filter(\.isSelected).map(\.draft)
    }

    private var primaryArtifactDrafts: [CaptureArtifactDraft] {
        var drafts = stagedArtifactDrafts
        if let text = bodyText.trimmedOrNil {
            drafts.insert(.text(title: nil, body: text, origin: .manual), at: 0)
        }
        return drafts
    }

    private var allArtifactDrafts: [CaptureArtifactDraft] {
        primaryArtifactDrafts + selectedContextDrafts
    }

    private var canSave: Bool {
        !isSaving && !isProcessingPhoto && !primaryArtifactDrafts.isEmpty
    }

    @MainActor
    private var attachmentItems: [CaptureComposerAttachmentItem] {
        var items: [CaptureComposerAttachmentItem] = []
        if isProcessingPhoto {
            items.append(.processing(id: "photo", detail: String(localized: "capture.photo.analyzing")))
        }
        if isRefiningVoiceTranscript {
            items.append(.processing(id: "voice", detail: "Refining voice transcript"))
        }
        if isCollectingContext {
            items.append(.processing(id: "context", detail: String(localized: "capture.context.collecting")))
        }
        items.append(contentsOf: stagedArtifactDrafts.indices.map { index in
            .staged(index: index, draft: stagedArtifactDrafts[index])
        })
        items.append(contentsOf: contextCandidates.map(CaptureComposerAttachmentItem.context))
        return items
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        CaptureAttachmentCarouselView(
                            items: attachmentItems,
                            onRemoveStagedArtifact: removeStagedArtifact(at:),
                            onToggleContextCandidate: toggleContextCandidate(id:)
                        )

                        CaptureBodyEditorView(
                            text: $bodyText,
                            focus: $isBodyFocused,
                            minHeight: max(proxy.size.height - (attachmentItems.isEmpty ? 0 : 132), 360)
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .top) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("common.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                    }
                    .disabled(!canSave)
                    .tint(.accentColor)
                    .accessibilityLabel("common.save")
                }

                CaptureComposerToolbar(
                    selectedPhotoItems: $selectedPhotoItems,
                    isTextInputFocused: isBodyFocused,
                    isProcessingPhoto: isProcessingPhoto,
                    isCollectingContext: isCollectingContext,
                    onCamera: { isPresentingCamera = true },
                    onAudio: { isPresentingAudioCapture = true },
                    onLink: { isPresentingLinkCapture = true },
                    onMusic: { isPresentingMusicCapture = true },
                    onLocation: { isPresentingLocationPicker = true },
                    onTodo: { isPresentingTodoCapture = true },
                    onRefreshContext: { Task { await refreshAutoContext() } }
                )
            }
            .sheet(isPresented: $isPresentingCamera) {
                UnifiedCameraCaptureView { image in
                    Task { await addCameraImage(image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isPresentingAudioCapture) {
                UnifiedAudioCaptureSheet { draft, transcript in
                    if let transcript = transcript.trimmedOrNil {
                        appendTranscriptToBody(transcript)
                    }
                    stagedArtifactDrafts.append(draft.withOrigin(.manual))
                }
            }
            .sheet(isPresented: $isPresentingLinkCapture) {
                UnifiedLinkCaptureSheet { draft in
                    stagedArtifactDrafts.append(draft.withOrigin(.manual))
                }
            }
            .sheet(isPresented: $isPresentingMusicCapture) {
                UnifiedMusicCaptureSheet { draft in
                    stagedArtifactDrafts.append(draft.withOrigin(.manual))
                }
            }
            .sheet(isPresented: $isPresentingLocationPicker) {
                LocationPickerView(initialSelection: nil) { draft in
                    stagedArtifactDrafts.append(draft.withOrigin(.manual))
                }
            }
            .sheet(isPresented: $isPresentingTodoCapture) {
                UnifiedTodoCaptureSheet { draft in
                    stagedArtifactDrafts.append(draft.withOrigin(.manual))
                }
            }
            .task {
                applySeedIfNeeded()
                await refineVoiceSeedIfNeeded()
                await loadInitialAutoContextIfNeeded()
                if seed.opensCameraOnAppear {
                    isBodyFocused = false
                    if !isPresentingCamera {
                        isPresentingCamera = true
                    }
                } else {
                    isBodyFocused = seed.voiceResult == nil
                }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                Task { await addPhotoItems(items) }
            }
        }
    }

    @MainActor
    private func applySeedIfNeeded() {
        guard let voice = seed.voiceResult, stagedArtifactDrafts.isEmpty, bodyText.isEmpty else { return }
        let transcript = voice.transcription.trimmedOrNil
        bodyText = transcript ?? ""
        generatedTitle = transcript?.generatedMemoryTitle() ?? String(localized: "quickCapture.voice.defaultTitle")
        stagedArtifactDrafts.append(.audio(
            title: String(localized: "quickCapture.voice.defaultTitle"),
            summary: String(localized: "quickCapture.voice.defaultSummary"),
            filename: voice.filename,
            audioData: voice.audioData,
            transcriptionText: transcript ?? "",
            origin: .manual
        ))
    }

    @MainActor
    private func refineVoiceSeedIfNeeded() async {
        guard !didAttemptVoiceRefinement else { return }
        guard let voice = seed.voiceResult, let rawTranscript = voice.transcription.trimmedOrNil else { return }
        didAttemptVoiceRefinement = true

        let preferences: IntelligencePreferences
        do {
            preferences = try memoryRepository.fetchIntelligencePreferences()
        } catch {
            preferences = .defaults
        }

        isRefiningVoiceTranscript = true
        defer { isRefiningVoiceTranscript = false }

        do {
            let service = VoiceTranscriptRefinementService(cloudIntelligenceService: cloudIntelligenceService)
            guard let refinement = try await service.refine(
                rawTranscript: rawTranscript,
                localeIdentifier: Locale.current.identifier,
                preferences: preferences
            ) else {
                return
            }
            applyVoiceRefinement(refinement, voice: voice)
        } catch {
            return
        }
    }

    @MainActor
    private func applyVoiceRefinement(_ refinement: VoiceTranscriptRefinement, voice: QuickVoiceCaptureResult) {
        bodyText = refinement.transcript
        if let suggestedTitle = refinement.suggestedTitle {
            generatedTitle = suggestedTitle
        } else if generatedTitle.trimmedOrNil == nil {
            generatedTitle = refinement.transcript.generatedMemoryTitle() ?? String(localized: "quickCapture.voice.defaultTitle")
        }

        guard let index = stagedArtifactDrafts.firstIndex(where: { draft in
            if case let .audio(_, _, filename, _, _, _) = draft {
                return filename == voice.filename
            }
            return false
        }) else { return }

        if case let .audio(existingTitle, _, filename, audioData, _, origin) = stagedArtifactDrafts[index] {
            stagedArtifactDrafts[index] = .audio(
                title: existingTitle,
                summary: String(localized: "quickCapture.voice.defaultSummary"),
                filename: filename,
                audioData: audioData,
                transcriptionText: refinement.transcript,
                origin: origin
            )
        }
    }

    private func loadInitialAutoContextIfNeeded() async {
        guard !hasLoadedInitialContext else { return }
        hasLoadedInitialContext = true
        await refreshAutoContext()
    }

    @MainActor
    private func refreshAutoContext() async {
        guard !isCollectingContext else { return }
        isCollectingContext = true
        defer { isCollectingContext = false }
        let collectedAt = Date.now
        let drafts = await ContextAutoCollector().collectContextDrafts()
        contextCandidates = drafts.map { draft in
            ContextCandidate(draft: draft.withOrigin(.context), capturedAt: collectedAt, isSelected: true)
        }
    }

    @MainActor
    private func addPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessingPhoto = true
        defer {
            isProcessingPhoto = false
            selectedPhotoItems = []
        }

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                await addPhotoData(data, filename: "photo_\(Int(Date().timeIntervalSince1970)).jpg")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.86) else { return }
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        await addPhotoData(data, filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg")
    }

    @MainActor
    private func addPhotoData(_ data: Data, filename: String) async {
        let result = await PhotoArtifactProcessor().process(imageData: data, filename: filename)
        let summary = result.summary.trimmedOrNil ?? String(localized: "quickCapture.photo.defaultSummary")
        stagedArtifactDrafts.append(.photo(
            title: nil,
            summary: summary,
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata,
            origin: .manual
        ))
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let rawText = bodyText.trimmedOrNil
                ?? stagedArtifactDrafts.map(\.captureComposerDetail).joined(separator: "\n").trimmedOrNil
                ?? "Untitled Memory"
            let draft = MemoryCaptureDraft(
                title: resolvedInternalTitle(rawText: rawText),
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                captureSource: resolvedCaptureSource,
                artifacts: allArtifactDrafts
            )
            _ = try await CaptureOrchestrator(memoryRepository: memoryRepository).capture(draft: draft)
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func removeStagedArtifact(at index: Int) {
        guard stagedArtifactDrafts.indices.contains(index) else { return }
        stagedArtifactDrafts.remove(at: index)
    }

    @MainActor
    private func toggleContextCandidate(id: UUID) {
        guard let index = contextCandidates.firstIndex(where: { $0.id == id }) else { return }
        contextCandidates[index].isSelected.toggle()
    }

    @MainActor
    private func appendTranscriptToBody(_ transcript: String) {
        if bodyText.trimmedOrNil == nil {
            bodyText = transcript
            return
        }
        bodyText += "\n" + transcript
    }

    private func resolvedInternalTitle(rawText: String) -> String {
        generatedTitle.generatedMemoryTitle()
            ?? rawText.generatedMemoryTitle()
            ?? "Untitled Memory"
    }

    private var resolvedCaptureSource: CaptureSource {
        if allArtifactDrafts.contains(where: { draft in
            if case .audio = draft { return true }
            return false
        }) {
            return .audio
        }
        if allArtifactDrafts.contains(where: { draft in
            if case .photo = draft { return true }
            return false
        }) {
            return .photo
        }
        return .composer
    }
}

private struct UnifiedAudioCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = AudioRecorderModel()

    let onAdd: (CaptureArtifactDraft, String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if recorder.isRecording {
                    HStack(spacing: 8) {
                        Image(systemName: "record.circle.fill")
                            .foregroundStyle(.red)
                        Text("Recording \(Int(recorder.recordingDuration))s")
                            .font(.subheadline.weight(.semibold))
                    }
                }

                if let failure = recorder.errorMessage {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if recorder.isStopping || recorder.isTranscribing {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(recorder.isTranscribing ? "Transcribing..." : "Finishing...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let transcript = resolvedTranscript {
                    ScrollView {
                        Text(transcript)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("Start recording and attach voice to this memory.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task {
                            await recorder.cancelRecording()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let output = recorder.recordedAudioData else { return }
                        let transcript = resolvedTranscript ?? ""
                        let filename = recorder.recordedFilename ?? "audio_\(Int(Date().timeIntervalSince1970)).caf"
                        let draft = CaptureArtifactDraft.audio(
                            title: nil,
                            summary: "Voice note",
                            filename: filename,
                            audioData: output,
                            transcriptionText: transcript,
                            origin: .manual
                        )
                        onAdd(draft, transcript)
                        dismiss()
                    }
                    .disabled(recorder.recordedAudioData == nil || recorder.isBusy)
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        if recorder.isRecording {
                            Button("Stop") {
                                Task { _ = await recorder.stopAndTranscribe() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            Button("Record") {
                                Task { await recorder.startRecording() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(recorder.isBusy)
                        }
                        Spacer()
                        if recorder.recordedAudioData != nil {
                            Button("Retry") {
                                recorder.clearRecording()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var resolvedTranscript: String? {
        recorder.finalTranscription.trimmedOrNil ?? recorder.liveTranscription.trimmedOrNil
    }
}

private struct UnifiedLinkCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlText = ""
    @State private var noteText = ""
    @State private var metadata: LinkMetadataResult?
    @State private var isFetching = false
    @State private var errorMessage: String?

    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("URL", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            Task { await fetchMetadata() }
                        }
                    TextField("Note", text: $noteText, axis: .vertical)
                        .lineLimit(2...5)
                }

                if isFetching {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading preview...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let metadata {
                    Section("Preview") {
                        if let title = metadata.title?.trimmedOrNil {
                            Text(title).font(.subheadline.weight(.semibold))
                        }
                        if let summary = metadata.summary?.trimmedOrNil {
                            Text(summary).font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(metadata.url).font(.caption).foregroundStyle(.tertiary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(makeDraft())
                        dismiss()
                    }
                    .disabled(urlText.trimmedOrNil == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Refresh Preview") {
                        Task { await fetchMetadata() }
                    }
                    .disabled(urlText.trimmedOrNil == nil || isFetching)
                }
            }
        }
    }

    private func fetchMetadata() async {
        guard let normalizedURL = urlText.trimmedOrNil else { return }
        isFetching = true
        defer { isFetching = false }
        metadata = await LinkMetadataExtractor().extract(urlString: normalizedURL)
        errorMessage = metadata == nil ? "Could not load link preview." : nil
    }

    private func makeDraft() -> CaptureArtifactDraft {
        let url = metadata?.url.trimmedOrNil ?? urlText.trimmedOrNil ?? ""
        return .link(
            title: metadata?.title,
            url: url,
            note: noteText.trimmedOrNil,
            summary: metadata?.summary,
            metadata: metadata?.metadata ?? ["url": url],
            thumbnailData: metadata?.imageData,
            origin: .manual
        )
    }
}

private struct UnifiedMusicCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MusicCatalogSongCandidate] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private let musicService = MusicContextService()
    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await addNowPlaying() }
                    } label: {
                        Label("Add currently playing song", systemImage: "music.note")
                    }

                    TextField("Search songs", text: $query)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await searchSongs() }
                        }

                    Button {
                        Task { await searchSongs() }
                    } label: {
                        Label(isSearching ? "Searching..." : "Search", systemImage: "magnifyingglass")
                    }
                    .disabled(isSearching || query.trimmedOrNil == nil)
                }

                if isSearching {
                    Section {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Searching Apple Music catalog...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { song in
                            Button {
                                onAdd(song.toDraft(origin: .manual))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(song.title)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)
                                    Text([song.artistName, song.albumTitle].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func addNowPlaying() async {
        if let draft = await musicService.captureNowPlaying(origin: .manual) {
            onAdd(draft)
            errorMessage = nil
            return
        }
        errorMessage = "No currently playing song available."
    }

    @MainActor
    private func searchSongs() async {
        guard let normalized = query.trimmedOrNil else { return }
        isSearching = true
        defer { isSearching = false }
        let songs = await musicService.searchSongs(query: normalized, limit: 20)
        results = songs
        errorMessage = songs.isEmpty ? "No songs found." : nil
    }
}

private struct UnifiedTodoCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var note = ""
    let onAdd: (CaptureArtifactDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard let resolvedTitle = title.trimmedOrNil else { return }
                        onAdd(.todo(title: resolvedTitle, note: note.trimmedOrNil, origin: .manual))
                        dismiss()
                    }
                    .disabled(title.trimmedOrNil == nil)
                }
            }
        }
    }
}

private struct UnifiedCameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onCapture: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onCapture: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onCapture = onCapture
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

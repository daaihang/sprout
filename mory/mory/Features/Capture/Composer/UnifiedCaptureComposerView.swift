import PhotosUI
import SwiftUI
import UIKit

struct UnifiedCaptureSeed: Identifiable, Equatable {
    let id = UUID()
    var voiceResult: QuickVoiceCaptureResult?
    var externalDraft: MemoryCaptureDraft?
    var externalInboxItemID: UUID?
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

    static func externalDraft(_ draft: MemoryCaptureDraft, inboxItemID: UUID) -> UnifiedCaptureSeed {
        UnifiedCaptureSeed(externalDraft: draft, externalInboxItemID: inboxItemID)
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
    @State private var draftProvenance: CaptureProvenance = .manualComposer
    @State private var bodyTextProvenance: CaptureProvenance = .manualComposer
    @State private var affectDrafts: [AffectSnapshotDraft] = []
    @State private var stagedArtifactDrafts: [CaptureArtifactDraft] = []
    @State private var cardArrangementDraft = MemoryCardArrangementDraft()
    @State private var contextCandidates: [ContextCandidate] = []
    @State private var isCollectingContext = false
    @State private var hasLoadedInitialContext = false
    @State private var didApplySeed = false

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var sheetCoordinator = CaptureComposerSheetCoordinator()

    @State private var isProcessingPhoto = false
    @State private var isRefiningVoiceTranscript = false
    @State private var didAttemptVoiceRefinement = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isBodyFocused: Bool

    private var selectedContextDrafts: [CaptureArtifactDraft] {
        contextCandidates.map(\.draft)
    }

    private var primaryArtifactDrafts: [CaptureArtifactDraft] {
        var drafts = stagedArtifactDrafts
        if let text = bodyText.trimmedOrNil {
            drafts.insert(.text(title: nil, body: text, origin: bodyTextProvenance.artifactOrigin, provenance: bodyTextProvenance), at: 0)
        }
        return drafts
    }

    private var allArtifactDrafts: [CaptureArtifactDraft] {
        primaryArtifactDrafts + selectedContextDrafts
    }

    private var canSave: Bool {
        !isSaving && !isProcessingPhoto && !primaryArtifactDrafts.isEmpty
    }

    private var composerActionStrip: some View {
        CaptureComposerActionStrip(
            selectedPhotoItems: $selectedPhotoItems,
            isProcessingPhoto: isProcessingPhoto,
            isCollectingContext: isCollectingContext,
            onMood: { sheetCoordinator.present(.mood) },
            onJournaling: { presentJournalingImport() },
            onCamera: { sheetCoordinator.present(.camera) },
            onAudio: { sheetCoordinator.present(.audio) },
            onLink: { sheetCoordinator.present(.link) },
            onMusic: { sheetCoordinator.present(.music) },
            onLocation: { sheetCoordinator.present(.location) },
            onTodo: { sheetCoordinator.present(.todo) },
            onRefreshContext: { Task { await refreshAutoContext() } }
        )
    }

    @MainActor
    private var attachmentItems: [CaptureComposerAttachmentItem] {
        var items: [CaptureComposerAttachmentItem] = []
        if isProcessingPhoto {
            items.append(.processing(id: "photo", kind: .photo, detail: String(localized: "capture.photo.analyzing")))
        }
        if isRefiningVoiceTranscript {
            items.append(.processing(id: "voice", kind: .audio, detail: String(localized: "capture.voice.refiningTranscript")))
        }
        if isCollectingContext {
            items.append(.processing(id: "context", detail: String(localized: "capture.context.collecting")))
        }

        let groupedSessionIDs = journalingSuggestionSessionIDs
        items.append(contentsOf: groupedSessionIDs.map { sessionID in
            CaptureComposerAttachmentItem.journalingSuggestion(
                importSessionID: sessionID,
                artifacts: stagedArtifactDrafts.filter { $0.isJournalingSuggestion(in: sessionID) },
                affects: affectDrafts.filter { $0.isJournalingSuggestion(in: sessionID) }
            )
        })
        items.append(contentsOf: stagedArtifactDrafts.indices.map { index in
            let draft = stagedArtifactDrafts[index]
            guard draft.journalingSuggestionSessionID == nil else { return nil }
            return .staged(index: index, draft: draft)
        }.compactMap { $0 })
        items.append(contentsOf: affectDrafts.indices.map { index in
            let draft = affectDrafts[index]
            guard draft.journalingSuggestionSessionID == nil else { return nil }
            return .affect(index: index, draft: draft)
        }.compactMap { $0 })
        items.append(contentsOf: contextCandidates.map(CaptureComposerAttachmentItem.context))
        return items
    }

    @MainActor
    private var journalingSuggestionSessionIDs: [UUID] {
        let artifactSessionIDs = stagedArtifactDrafts.compactMap(\.journalingSuggestionSessionID)
        let affectSessionIDs = affectDrafts.compactMap(\.journalingSuggestionSessionID)
        return Array(Set(artifactSessionIDs + affectSessionIDs)).sorted { $0.uuidString < $1.uuidString }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
	                        CaptureAttachmentCarouselView(
	                            items: attachmentItems,
	                            onRemoveStagedArtifact: removeStagedArtifact(at:),
	                            onRemoveContextCandidate: removeContextCandidate(id:),
	                            onRemoveAffectDraft: removeAffectDraft(at:),
	                            onRemoveJournalingSuggestion: removeJournalingSuggestion(importSessionID:),
                                onReorderStagedArtifact: reorderStagedArtifact(from:to:),
                                onSetSize: setArrangementSize(for:size:),
                                onStackWithPrevious: stackArrangementNodeWithPrevious(item:),
                                onUnstack: unstackArrangementNode(item:)
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isBodyFocused {
                    composerActionStrip
                        .padding(.vertical, 2)
                        .background(.bar)
                        .overlay(alignment: .top) {
                            Divider()
                        }
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

                ToolbarItemGroup(placement: .keyboard) {
                    if isBodyFocused {
                        composerActionStrip
                    }
                }
            }
            .sheet(item: $sheetCoordinator.activeSheet) { sheet in
                sheetContent(for: sheet)
            }
            .appleJournalingSuggestionPicker(isPresented: $sheetCoordinator.isPresentingAppleJournalingPicker) { suggestion in
                mergeImportedJournalingSuggestion(suggestion)
            }
            .task {
                applySeedIfNeeded()
                await refineVoiceSeedIfNeeded()
                await loadInitialAutoContextIfNeeded()
                if seed.opensCameraOnAppear {
                    isBodyFocused = false
                    if sheetCoordinator.activeSheet != .camera {
                        sheetCoordinator.present(.camera)
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

    @ViewBuilder
    private func sheetContent(for sheet: CaptureComposerSheet) -> some View {
        switch sheet {
        case .camera:
            UnifiedCameraCaptureView { image in
                Task { await addCameraImage(image) }
            }
            .ignoresSafeArea()
        case .audio:
            UnifiedAudioCaptureSheet { draft, transcript in
                if let transcript = transcript.trimmedOrNil {
                    appendTranscriptToBody(transcript)
                }
                appendStagedArtifact(draft.withProvenance(manualProvenance(.audioRecorder)))
            }
        case .link:
            UnifiedLinkCaptureSheet { draft in
                appendStagedArtifact(draft.withProvenance(manualProvenance(.linkComposer)))
            }
        case .music:
            UnifiedMusicCaptureSheet { draft in
                appendStagedArtifact(draft.withProvenance(manualProvenance(.musicPicker)))
            }
        case .location:
            LocationPickerView(initialSelection: nil) { draft in
                appendStagedArtifact(draft.withProvenance(manualProvenance(.locationPicker)))
            }
        case .todo:
            UnifiedTodoCaptureSheet { draft in
                appendStagedArtifact(draft.withProvenance(manualProvenance(.todoComposer)))
            }
        case .mood:
            StructuredMoodPickerSheet(
                initialDraft: affectDrafts.first(where: { $0.sources.contains(.userSelected) }),
                onSave: { draft in
                    applyStructuredMoodDraft(draft)
                }
            )
        case .journalingFallback:
            JournalingSuggestionImportView { draft in
                mergeImportedDraft(draft)
            }
        }
    }

    @MainActor
    private func applySeedIfNeeded() {
        guard !didApplySeed else { return }
        didApplySeed = true

        if let externalDraft = seed.externalDraft {
            mergeImportedDraft(externalDraft)
            return
        }

        guard let voice = seed.voiceResult, stagedArtifactDrafts.isEmpty, bodyText.isEmpty else { return }
        let transcript = voice.transcription.trimmedOrNil
        draftProvenance = .manualVoice
        bodyTextProvenance = .manualVoice
        bodyText = transcript ?? ""
        generatedTitle = transcript?.generatedMemoryTitle() ?? String(localized: "quickCapture.voice.defaultTitle")
        appendStagedArtifact(.audio(
            title: String(localized: "quickCapture.voice.defaultTitle"),
            summary: String(localized: "quickCapture.voice.defaultSummary"),
            filename: voice.filename,
            audioData: voice.audioData,
            transcriptionText: transcript ?? "",
            origin: .manual,
            provenance: .manualVoice
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
            if case let .audio(c) = draft.content {
                return c.filename == voice.filename
            }
            return false
        }) else { return }

        if case let .audio(c) = stagedArtifactDrafts[index].content {
            var updated = c
            updated.transcriptionText = refinement.transcript
            stagedArtifactDrafts[index] = .audio(
                title: updated.title,
                summary: String(localized: "quickCapture.voice.defaultSummary"),
                filename: updated.filename,
                audioData: updated.audioData,
                transcriptionText: updated.transcriptionText,
                origin: stagedArtifactDrafts[index].origin,
                provenance: stagedArtifactDrafts[index].provenance
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
        let policy = (try? memoryRepository.fetchUserSettingsPreference().defaultContextSelection) ?? .allAvailable
        let drafts = await ContextAutoCollector().collectContextDrafts(policy: policy)
        contextCandidates = drafts.map { draft in
            ContextCandidate(draft: draft.withProvenance(.autoContext), capturedAt: collectedAt, isSelected: true)
        }
        syncCardArrangementDraft()
    }

    @MainActor
    private func addPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessingPhoto = true
        defer {
            isProcessingPhoto = false
            selectedPhotoItems = []
        }

        let processor = MediaArtifactProcessor()
        for item in items {
            do {
                let draft = try await processor.process(
                    item: item,
                    origin: .manual,
                    provenance: manualProvenance(.photoLibrary)
                )
                appendStagedArtifact(draft)
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
        appendStagedArtifact(.photo(
            title: nil,
            summary: summary,
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata,
            origin: .manual,
            provenance: manualProvenance(filename.hasPrefix("camera_") ? .camera : .photoLibrary)
        ))
    }

    @MainActor
    private func appendStagedArtifact(_ draft: CaptureArtifactDraft) {
        stagedArtifactDrafts.append(draft)
        cardArrangementDraft.appendArtifactDraft(draft)
    }

    @MainActor
    private func appendStagedArtifacts(_ drafts: [CaptureArtifactDraft]) {
        drafts.forEach(appendStagedArtifact)
    }

    @MainActor
    private func syncCardArrangementDraft() {
        cardArrangementDraft.sync(
            recordBodyIsPresent: bodyText.trimmedOrNil != nil,
            artifactDrafts: arrangementArtifactDrafts
        )
    }

    @MainActor
    private var arrangementArtifactDrafts: [CaptureArtifactDraft] {
        allArtifactDrafts.filter { draft in
            if case .text = draft.content {
                return false
            }
            return true
        }
    }

    @MainActor
    private func resolvedCardArrangementDraft(rawText: String) -> MemoryCardArrangementDraft {
        var arrangement = cardArrangementDraft
        arrangement.sync(
            recordBodyIsPresent: rawText.trimmedOrNil != nil,
            artifactDrafts: arrangementArtifactDrafts
        )
        return arrangement
    }

    @MainActor
    private func setArrangementSize(for item: CaptureComposerAttachmentItem, size: MemoryCardSizeToken) {
        guard let draftID = arrangementDraftID(for: item) else { return }
        cardArrangementDraft.setSize(size, forDraftID: draftID)
    }

    @MainActor
    private func stackArrangementNodeWithPrevious(item: CaptureComposerAttachmentItem) {
        guard let draftID = arrangementDraftID(for: item) else { return }
        cardArrangementDraft.toggleStackWithPrevious(draftID: draftID)
    }

    @MainActor
    private func unstackArrangementNode(item: CaptureComposerAttachmentItem) {
        guard let draftID = arrangementDraftID(for: item) else { return }
        cardArrangementDraft.unstackContainingDraft(draftID)
    }

    @MainActor
    private func arrangementDraftID(for item: CaptureComposerAttachmentItem) -> UUID? {
        switch item.source {
        case let .stagedArtifact(index):
            return stagedArtifactDrafts.indices.contains(index) ? stagedArtifactDrafts[index].draftID : nil
        case let .contextCandidate(id):
            return contextCandidates.first(where: { $0.id == id })?.draft.draftID
        case .affect, .journalingSuggestion, .processing:
            return nil
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let rawText = bodyText.trimmedOrNil
                ?? stagedArtifactDrafts.map { CaptureCardItem(draft: $0).detail }.joined(separator: "\n").trimmedOrNil
                ?? String(localized: "capture.memory.untitled")
            let draft = MemoryCaptureDraft(
                title: resolvedInternalTitle(rawText: rawText),
                rawText: rawText,
                mood: mood.trimmedOrNil,
                inputContext: inputContext.trimmedOrNil,
                provenance: draftProvenance,
                artifacts: allArtifactDrafts,
                affectSnapshots: affectDrafts,
                cardArrangement: resolvedCardArrangementDraft(rawText: rawText)
            )
            let memory = try await CaptureOrchestrator(memoryRepository: memoryRepository).capture(draft: draft)
            if let inboxItemID = seed.externalInboxItemID {
                try memoryRepository.markExternalCaptureInboxItemImported(inboxItemID, recordID: memory.record.id)
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func removeStagedArtifact(at index: Int) {
        guard stagedArtifactDrafts.indices.contains(index) else { return }
        let removed = stagedArtifactDrafts.remove(at: index)
        cardArrangementDraft.removeArtifactDraft(removed.draftID)
    }

    @MainActor
    private func reorderStagedArtifact(from sourceIndex: Int, to targetIndex: Int) {
        guard stagedArtifactDrafts.indices.contains(sourceIndex),
              stagedArtifactDrafts.indices.contains(targetIndex),
              sourceIndex != targetIndex else {
            return
        }
        withAnimation(.snappy(duration: 0.2)) {
            let sourceDraftID = stagedArtifactDrafts[sourceIndex].draftID
            let targetDraftID = stagedArtifactDrafts[targetIndex].draftID
            let item = stagedArtifactDrafts.remove(at: sourceIndex)
            let insertionIndex = sourceIndex < targetIndex ? targetIndex : targetIndex
            stagedArtifactDrafts.insert(item, at: insertionIndex)
            cardArrangementDraft.reorderArtifactDraft(from: sourceDraftID, to: targetDraftID)
        }
    }

    @MainActor
    private func removeAffectDraft(at index: Int) {
        guard affectDrafts.indices.contains(index) else { return }
        affectDrafts.remove(at: index)
        mood = affectDrafts.first?.labels.first?.rawValue
            ?? affectDrafts.first?.rawInput?.trimmedOrNil
            ?? ""
    }

    @MainActor
    private func removeContextCandidate(id: UUID) {
        guard let index = contextCandidates.firstIndex(where: { $0.id == id }) else { return }
        let removed = contextCandidates.remove(at: index)
        cardArrangementDraft.removeArtifactDraft(removed.draft.draftID)
    }

    @MainActor
    private func removeJournalingSuggestion(importSessionID: UUID) {
        let removedDraftIDs = stagedArtifactDrafts
            .filter { $0.isJournalingSuggestion(in: importSessionID) }
            .map(\.draftID)
        stagedArtifactDrafts.removeAll { $0.isJournalingSuggestion(in: importSessionID) }
        removedDraftIDs.forEach { cardArrangementDraft.removeArtifactDraft($0) }
        affectDrafts.removeAll { $0.isJournalingSuggestion(in: importSessionID) }
        mood = affectDrafts.first?.labels.first?.rawValue
            ?? affectDrafts.first?.rawInput?.trimmedOrNil
            ?? ""
    }

    @MainActor
    private func presentJournalingImport() {
        sheetCoordinator.presentJournalingImport(
            isApplePickerAvailable: JournalingSuggestionContextService().availability().isAvailable
        )
    }

    @MainActor
    private func appendTranscriptToBody(_ transcript: String) {
        if bodyText.trimmedOrNil == nil {
            bodyText = transcript
            return
        }
        bodyText += "\n" + transcript
    }

    @MainActor
    private func applyStructuredMoodDraft(_ draft: AffectSnapshotDraft) {
        var normalized = draft
        if !normalized.sources.contains(.userSelected) {
            normalized.sources.append(.userSelected)
        }
        if normalized.provenance == nil {
            normalized.provenance = manualProvenance(.moodPicker)
        }
        if let index = affectDrafts.firstIndex(where: { $0.sources.contains(.userSelected) }) {
            affectDrafts[index] = normalized
        } else {
            affectDrafts.insert(normalized, at: 0)
        }
        mood = normalized.labels.first?.rawValue
            ?? normalized.rawInput?.trimmedOrNil
            ?? mood
    }

    @MainActor
    private func mergeImportedDraft(_ draft: MemoryCaptureDraft) {
        draftProvenance = draft.provenance
        if let title = draft.title?.trimmedOrNil, generatedTitle.trimmedOrNil == nil {
            generatedTitle = title
        }
        if let importedRawText = draft.rawText.trimmedOrNil {
            if bodyText.trimmedOrNil == nil {
                bodyTextProvenance = draft.provenance
            }
            appendTranscriptToBody(importedRawText)
        }
        if let importedContext = draft.inputContext?.trimmedOrNil {
            if let existing = inputContext.trimmedOrNil {
                if !existing.contains(importedContext) {
                    inputContext = existing + "\n" + importedContext
                }
            } else {
                inputContext = importedContext
            }
        }
        let nonTextArtifacts = draft.artifacts.filter { artifact in
            if case .text = artifact.content { return false }
            return true
        }
        appendStagedArtifacts(nonTextArtifacts)
        if let importedArrangement = draft.cardArrangement {
            cardArrangementDraft.mergeArrangement(importedArrangement)
            syncCardArrangementDraft()
        }
        if !draft.affectSnapshots.isEmpty {
            affectDrafts.append(contentsOf: draft.affectSnapshots)
            mood = draft.affectSnapshots.first?.labels.first?.rawValue
                ?? draft.affectSnapshots.first?.rawInput?.trimmedOrNil
                ?? mood
        } else if let importedMood = draft.mood?.trimmedOrNil {
            mood = importedMood
        }
    }

    @MainActor
    private func mergeImportedJournalingSuggestion(_ suggestion: JournalingSuggestionDraft) {
        let draft = JournalingSuggestionContextService().makeCaptureDraft(from: suggestion)
        mergeImportedDraft(draft)
    }

    private func resolvedInternalTitle(rawText: String) -> String {
        generatedTitle.generatedMemoryTitle()
            ?? rawText.generatedMemoryTitle()
            ?? String(localized: "capture.memory.untitled")
    }

    private func manualProvenance(_ sourceKind: CaptureProvenanceSourceKind) -> CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: sourceKind)
    }
}

private extension CaptureArtifactDraft {
    var journalingSuggestionSessionID: UUID? {
        guard provenance?.sourceKind == .journalingSuggestion else { return nil }
        return provenance?.importSessionID
    }

    func isJournalingSuggestion(in importSessionID: UUID) -> Bool {
        journalingSuggestionSessionID == importSessionID
    }
}

private extension AffectSnapshotDraft {
    var journalingSuggestionSessionID: UUID? {
        guard provenance?.sourceKind == .journalingSuggestion else { return nil }
        return provenance?.importSessionID
    }

    func isJournalingSuggestion(in importSessionID: UUID) -> Bool {
        journalingSuggestionSessionID == importSessionID
    }
}

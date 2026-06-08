import PhotosUI
import QuickLook
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
    @State private var isRecordBodyCardVisible = false
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
    @State private var previewCoordinator = MemoryCardPreviewCoordinator()
    @State private var previewURL: URL?
    @State private var previewURLs: [URL] = []
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

    private func composerAddMenu(labelStyle: MemoryAddCardMenu.LabelStyle) -> some View {
        MemoryAddCardMenu(
            selectedPhotoItems: $selectedPhotoItems,
            labelStyle: labelStyle,
            isProcessingPhoto: isProcessingPhoto,
            isCollectingContext: isCollectingContext,
            includesText: true,
            includesMood: true,
            includesJournaling: true,
            includesContextRefresh: true,
            onText: { showRecordBodyCard(focus: true) },
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
        items.append(contentsOf: arrangedArtifactItems)
        items.append(contentsOf: affectDrafts.indices.map { index in
            let draft = affectDrafts[index]
            guard draft.journalingSuggestionSessionID == nil else { return nil }
            return .affect(index: index, draft: draft)
        }.compactMap { $0 })
        return items
    }

    @MainActor
    private var arrangedArtifactItems: [CaptureComposerAttachmentItem] {
        let draftByID = Dictionary(uniqueKeysWithValues: arrangementArtifactDrafts.map { ($0.draftID, $0) })
        let orderedNodes = cardArrangementDraft.nodes.sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
        return orderedNodes.flatMap { node -> [CaptureComposerAttachmentItem] in
            switch node.contentRef {
            case let .artifactDraft(draftID):
                guard let draft = draftByID[draftID],
                      draft.journalingSuggestionSessionID == nil,
                      let item = attachmentItem(forDraftID: draftID) else {
                    return []
                }
                return [item]
            case let .artifactDraftGroup(draftIDs, _):
                let drafts = draftIDs.compactMap { draftByID[$0] }
                    .filter { $0.journalingSuggestionSessionID == nil }
                guard !drafts.isEmpty else { return [] }
                if drafts.allSatisfy(\.isMemoryCardMergeableMedia),
                   let groupItem = CaptureComposerAttachmentItem.draftGroup(nodeID: node.id, drafts: drafts) {
                    return [groupItem]
                }
                return drafts.compactMap { attachmentItem(forDraftID: $0.draftID) }
            case .recordBody, .affectDraft, .journalingSuggestion:
                return []
            }
        }
    }

    @MainActor
    private func attachmentItem(forDraftID draftID: UUID) -> CaptureComposerAttachmentItem? {
        if let index = stagedArtifactDrafts.firstIndex(where: { $0.draftID == draftID }) {
            return .staged(index: index, draft: stagedArtifactDrafts[index])
        }
        if let candidate = contextCandidates.first(where: { $0.draft.draftID == draftID }) {
            return .context(candidate)
        }
        return nil
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
                        CaptureAttachmentCompactBoardView(
                            items: attachmentItems,
                            onRemoveStagedArtifact: removeStagedArtifact(at:),
                            onRemoveContextCandidate: removeContextCandidate(id:),
                            onRemoveDraftGroup: removeDraftGroup(_:),
                            onRemoveAffectDraft: removeAffectDraft(at:),
                            onRemoveJournalingSuggestion: removeJournalingSuggestion(importSessionID:),
                            onReorderItems: reorderAttachmentItem(from:to:),
                            onStackWithPrevious: stackArrangementNodeWithPrevious(item:),
                            onUnstack: unstackArrangementNode(item:),
                            onSetDensity: setAttachmentItemDensity(item:density:),
                            onPreview: previewAttachmentItem(_:),
                            presentationForItem: presentationForAttachmentItem(_:),
                            layoutForItem: layoutForAttachmentItem(_:)
                        )

                        if isRecordBodyCardVisible {
                            RecordBodyCardEditor(
                                text: $bodyText,
                                focus: $isBodyFocused,
                                minHeight: max(proxy.size.height - (attachmentItems.isEmpty ? 260 : 360), 160)
                            )
                            .padding(.horizontal, 20)
                            .padding(.top, attachmentItems.isEmpty ? 16 : 12)
                            .contextMenu {
                                Button {
                                    isBodyFocused = true
                                } label: {
                                    Label("memory.card.edit", systemImage: "pencil")
                                }
                            }
                        }

                        composerAddMenu(labelStyle: .footer)
                            .padding(.top, isRecordBodyCardVisible || !attachmentItems.isEmpty ? 16 : 28)
                            .padding(.bottom, 28)
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
                    HStack {
                        Spacer()
                        composerAddMenu(labelStyle: .toolbar)
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(.vertical, 8)
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
                        composerAddMenu(labelStyle: .toolbar)
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
                    isBodyFocused = isRecordBodyCardVisible && seed.voiceResult == nil
                }
            }
            .onChange(of: selectedPhotoItems) { _, items in
                Task { await addPhotoItems(items) }
            }
            .sheet(isPresented: Binding(
                get: { !previewURLs.isEmpty },
                set: { isPresented in
                    if !isPresented {
                        previewURLs = []
                        previewURL = nil
                    }
                }
            )) {
                MemoryCardPreviewSheet(urls: previewURLs)
            }
            .onDisappear {
                previewCoordinator.clearTemporaryFiles()
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
        isRecordBodyCardVisible = transcript != nil
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
        isRecordBodyCardVisible = true
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
                languageCode: updated.languageCode,
                transcriptionConfidence: updated.transcriptionConfidence,
                durationSeconds: updated.durationSeconds,
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

        let result = await MemoryCardDraftMediaAdder.drafts(fromPhotoItems: items)
        appendStagedArtifacts(result.drafts)
        if let message = result.firstErrorMessage {
            errorMessage = message
        }
    }

    @MainActor
    private func addCameraImage(_ image: UIImage) async {
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        if let draft = await MemoryCardDraftMediaAdder.draft(fromCameraImage: image) {
            appendStagedArtifact(draft)
        }
    }

    @MainActor
    private func addPhotoData(_ data: Data, filename: String) async {
        let sourceKind: CaptureProvenanceSourceKind = filename.hasPrefix("camera_") ? .camera : .photoLibrary
        let draft = await MemoryCardDraftMediaAdder.draft(
            fromPhotoData: data,
            filename: filename,
            provenance: MemoryCardDraftMediaAdder.manualProvenance(sourceKind)
        )
        appendStagedArtifact(draft)
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
    private func presentationForAttachmentItem(_ item: CaptureComposerAttachmentItem) -> CaptureCardPresentation {
        guard let node = arrangementNode(for: item) else {
            return .composerAttachment(item)
        }
        return .composerAttachment(
            item,
            contentDensity: node.contentDensity
        )
    }

    @MainActor
    private func layoutForAttachmentItem(_ item: CaptureComposerAttachmentItem) -> MemoryCardLayoutToken? {
        arrangementNode(for: item)?.layout
    }

    @MainActor
    private func arrangementNode(for item: CaptureComposerAttachmentItem) -> MemoryCardDraftNode? {
        if case let .draftGroup(nodeID, _) = item.source {
            return cardArrangementDraft.nodes.first { $0.id == nodeID }
        }
        guard let draftID = arrangementDraftID(for: item) else { return nil }
        return cardArrangementDraft.nodes.first { node in
            switch node.contentRef {
            case let .artifactDraft(id):
                return id == draftID
            case let .artifactDraftGroup(ids, _):
                return ids.contains(draftID)
            case .recordBody, .affectDraft, .journalingSuggestion:
                return false
            }
        }
    }

    @MainActor
    private func stackArrangementNodeWithPrevious(item: CaptureComposerAttachmentItem) {
        MemoryCardArrangementDraftEditing.stackWithPrevious(
            item: item,
            drafts: arrangementArtifactDrafts,
            arrangement: &cardArrangementDraft
        )
    }

    @MainActor
    private func unstackArrangementNode(item: CaptureComposerAttachmentItem) {
        MemoryCardArrangementDraftEditing.unstack(
            item: item,
            drafts: arrangementArtifactDrafts,
            arrangement: &cardArrangementDraft
        )
    }

    @MainActor
    private func previewAttachmentItem(_ item: CaptureComposerAttachmentItem) {
        if case let .music(payload) = item.card.payload {
            toggleMusic(payload)
            return
        }

        do {
            switch item.source {
            case let .stagedArtifact(index):
                guard stagedArtifactDrafts.indices.contains(index) else { return }
                presentPreviewURLs(try previewCoordinator.previewURLs(for: [stagedArtifactDrafts[index]]))
            case let .contextCandidate(id):
                guard let draft = contextCandidates.first(where: { $0.id == id })?.draft else { return }
                presentPreviewURLs(try previewCoordinator.previewURLs(for: [draft]))
            case let .draftGroup(_, draftIDs):
                let draftByID = Dictionary(uniqueKeysWithValues: arrangementArtifactDrafts.map { ($0.draftID, $0) })
                let drafts = draftIDs.compactMap { draftByID[$0] }
                presentPreviewURLs(try previewCoordinator.previewURLs(for: drafts))
            case let .affect(index):
                guard affectDrafts.indices.contains(index) else { return }
                presentPreviewURLs(try previewCoordinator.previewURLs(forAffectDrafts: [affectDrafts[index]]))
            case let .journalingSuggestion(importSessionID):
                let drafts = stagedArtifactDrafts.filter { $0.isJournalingSuggestion(in: importSessionID) }
                let affects = affectDrafts.filter { $0.isJournalingSuggestion(in: importSessionID) }
                let urls = try previewCoordinator.previewURLs(for: drafts)
                    + previewCoordinator.previewURLs(forAffectDrafts: affects)
                presentPreviewURLs(urls)
            case .processing:
                return
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggleMusic(_ payload: CaptureMusicCardPayload) {
        Task {
            do {
                _ = try await MoryMusicPlaybackController.togglePlayback(for: payload)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func presentPreviewURLs(_ urls: [URL]) {
        guard let first = urls.first else { return }
        previewURLs = urls
        previewURL = first
    }

    @MainActor
    private func showRecordBodyCard(focus: Bool) {
        isRecordBodyCardVisible = true
        if focus {
            isBodyFocused = true
        }
    }

    @MainActor
    private func reorderAttachmentItem(from source: CaptureComposerAttachmentItem, to target: CaptureComposerAttachmentItem) {
        if case let .stagedArtifact(sourceIndex) = source.source,
           case let .stagedArtifact(targetIndex) = target.source {
            reorderStagedArtifact(from: sourceIndex, to: targetIndex)
            return
        }
        guard let sourceDraftID = arrangementDraftID(for: source),
              let targetDraftID = arrangementDraftID(for: target),
              sourceDraftID != targetDraftID else {
            return
        }
        withAnimation(.snappy(duration: 0.2)) {
            cardArrangementDraft.reorderArtifactDraft(from: sourceDraftID, to: targetDraftID)
        }
    }

    @MainActor
    private func setAttachmentItemDensity(item: CaptureComposerAttachmentItem, density: MemoryCardContentDensity) {
        withAnimation(.snappy(duration: 0.18)) {
            if case .contextCandidate = item.source {
                guard let draftID = arrangementDraftID(for: item) else { return }
                cardArrangementDraft.setContentDensity(density, forDraftID: draftID)
            } else {
                MemoryCardArrangementDraftEditing.setDensity(
                    density,
                    for: item,
                    drafts: arrangementArtifactDrafts,
                    arrangement: &cardArrangementDraft
                )
            }
        }
    }

    @MainActor
    private func arrangementDraftID(for item: CaptureComposerAttachmentItem) -> UUID? {
        switch item.source {
        case let .stagedArtifact(index):
            return stagedArtifactDrafts.indices.contains(index) ? stagedArtifactDrafts[index].draftID : nil
        case let .contextCandidate(id):
            return contextCandidates.first(where: { $0.id == id })?.draft.draftID
        case let .draftGroup(_, draftIDs):
            return draftIDs.first
        case let .journalingSuggestion(importSessionID):
            return stagedArtifactDrafts.first { draft in
                guard draft.isJournalingSuggestion(in: importSessionID) else { return false }
                if case .text = draft.content { return false }
                return true
            }?.draftID
        case .affect, .processing:
            return nil
        }
    }

    @MainActor
    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let rawText = bodyText.trimmedOrNil ?? ""
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
        cardArrangementDraft.removeArtifactDraft(removed.draftID, artifactDrafts: arrangementArtifactDrafts)
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
            let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
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
        cardArrangementDraft.removeArtifactDraft(removed.draft.draftID, artifactDrafts: arrangementArtifactDrafts)
    }

    @MainActor
    private func removeDraftGroup(_ draftIDs: [UUID]) {
        guard !draftIDs.isEmpty else { return }
        let ids = Set(draftIDs)
        stagedArtifactDrafts.removeAll { ids.contains($0.draftID) }
        contextCandidates.removeAll { ids.contains($0.draft.draftID) }
        draftIDs.forEach { cardArrangementDraft.removeArtifactDraft($0, artifactDrafts: arrangementArtifactDrafts) }
    }

    @MainActor
    private func removeJournalingSuggestion(importSessionID: UUID) {
        let removedDraftIDs = stagedArtifactDrafts
            .filter { $0.isJournalingSuggestion(in: importSessionID) }
            .map(\.draftID)
        stagedArtifactDrafts.removeAll { $0.isJournalingSuggestion(in: importSessionID) }
        removedDraftIDs.forEach { cardArrangementDraft.removeArtifactDraft($0, artifactDrafts: arrangementArtifactDrafts) }
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
        isRecordBodyCardVisible = true
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
            isRecordBodyCardVisible = true
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
        if let importedArrangement = draft.cardArrangement {
            cardArrangementDraft.mergeArrangement(importedArrangement)
        }
        let nonTextArtifacts = draft.artifacts.filter { artifact in
            if case .text = artifact.content { return false }
            return true
        }
        appendStagedArtifacts(nonTextArtifacts)
        if draft.cardArrangement != nil {
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
            ?? primaryArtifactDrafts.lazy.map(\.captureSummary).compactMap { $0.generatedMemoryTitle() }.first
            ?? String(localized: "capture.memory.untitled")
    }

    private func manualProvenance(_ sourceKind: CaptureProvenanceSourceKind) -> CaptureProvenance {
        MemoryCardDraftMediaAdder.manualProvenance(sourceKind)
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

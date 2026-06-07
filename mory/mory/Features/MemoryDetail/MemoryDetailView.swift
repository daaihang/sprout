import PhotosUI
import SwiftUI
import UIKit

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false
    @State private var isReloading = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftRawText = ""
    @State private var isDraftRecordBodyCardVisible = false
    @State private var draftArtifactOrder: [UUID] = []
    @State private var draftCardArrangement: MemoryCardArrangement?
    @State private var draftDeletedArtifactIDs: Set<UUID> = []
    @State private var draftAddedArtifactDrafts: [CaptureArtifactDraft] = []
    @State private var draftAddedCardArrangement = MemoryCardArrangementDraft()
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var detailSheetCoordinator = CaptureComposerSheetCoordinator()
    @State private var isProcessingPhoto = false
    @State private var isSavingEdits = false
    @State private var isConfirmingDiscardEdits = false
    @State private var previewCoordinator = MemoryCardPreviewCoordinator()
    @State private var previewURLs: [URL] = []
    @State private var previewDeleteArtifactIDs: [UUID] = []
    @State private var pendingDeleteArtifactIDs: [UUID] = []
    @State private var isConfirmingCardDeletion = false

    private let productPathPolicy = MemoryDetailProductPathPolicy()

    var body: some View {
        Group {
            if let snapshot {
                if isEditing {
                    MemoryDetailEditingView(
                        title: $draftTitle,
                        rawText: $draftRawText,
                        isRecordBodyCardVisible: $isDraftRecordBodyCardVisible,
                        artifacts: draftEditableArtifacts,
                        cardArrangement: draftCardArrangement,
                        addedDraftItems: draftAddedAttachmentItems,
                        errorMessage: errorMessage,
                        onDeleteArtifacts: { artifactIDs in
                            requestDeleteArtifacts(artifactIDs)
                        },
                        onPreviewArtifacts: previewArtifacts(_:),
                        onSetCardDensity: setDraftCardDensity(nodeID:density:),
                        onStackArtifactWithPrevious: stackDraftArtifactWithPrevious(_:),
                        onUnstackArtifact: unstackDraftArtifact(_:),
                        onAutoArrange: autoArrangeDraftCards,
                        onRemoveAddedDraft: removeAddedDraft(at:),
                        onRemoveAddedDraftGroup: removeAddedDraftGroup(_:),
                        onPreviewAddedDraft: previewAddedDraftItem(_:),
                        onSetAddedDraftDensity: setAddedDraftDensity(item:density:),
                        onReorderAddedDraft: reorderAddedDraftItem(from:to:),
                        onStackAddedDraftWithPrevious: stackAddedDraftWithPrevious(item:),
                        onUnstackAddedDraft: unstackAddedDraft(item:)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            MemoryDeskRenderer(
                                snapshot: snapshot,
                                onPreviewRecord: previewRecord,
                                onPreviewArtifacts: previewArtifacts(_:),
                                onOpenPlace: openPlace(_:),
                                onOpenLink: openLink(_:),
                                onToggleMusic: toggleMusic(_:),
                                onEditMemory: beginEditing,
                                onSetCardDensity: setCardDensity(nodeID:density:),
                                onMergeMediaWithPrevious: mergeMediaWithPrevious(_:),
                                onUnmergeMedia: unmergeMedia(nodeID:),
                                onDeleteArtifacts: requestDeleteArtifacts(_:)
                            )
                            if productPathPolicy.exposesAnalysisDebugSurfaces {
                                MemoryDetailInsightPanel(snapshot: snapshot)
                            }
                        }
                        .padding(.vertical, 18)
                    }
                    .background(Color(.systemBackground))
                }
            } else if let errorMessage {
                ContentUnavailableView(
                    "memory.error.notFound",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .moryHidesTabChrome()
        .toolbar(content: detailToolbar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if snapshot != nil {
                HStack {
                    Spacer()
                    detailAddMenu(labelStyle: .toolbar)
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
        .task(id: recordID) {
            await load()
        }
        .refreshable {
            await load()
        }
        .confirmationDialog("memory.edit.discard.title", isPresented: $isConfirmingDiscardEdits) {
            Button("memory.edit.discard.action", role: .destructive) {
                discardEditDraft()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("memory.edit.discard.message")
        }
        .confirmationDialog("memory.card.delete.title", isPresented: $isConfirmingCardDeletion) {
            Button("common.delete", role: .destructive) {
                confirmPendingCardDeletion()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("memory.card.delete.message")
        }
        .sheet(item: $detailSheetCoordinator.activeSheet) { sheet in
            detailSheetContent(for: sheet)
        }
        .sheet(isPresented: Binding(
            get: { !previewURLs.isEmpty },
            set: { isPresented in
                if !isPresented {
                    previewURLs = []
                    previewDeleteArtifactIDs = []
                }
            }
        )) {
            MemoryCardPreviewSheet(
                urls: previewURLs,
                canDelete: !previewDeleteArtifactIDs.isEmpty,
                onDelete: { stageDeleteArtifacts(previewDeleteArtifactIDs) }
            )
        }
        .onChange(of: selectedPhotoItems) { _, items in
            Task { await addPhotoItems(items) }
        }
        .onDisappear {
            previewCoordinator.clearTemporaryFiles()
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipelineDidComplete)) { notification in
            if let id = notification.userInfo?["recordID"] as? UUID, id == recordID {
                Task { await load() }
            }
        }
    }

    @ToolbarContentBuilder
    private func detailToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            if isEditing {
                Button("memory.edit.cancel") {
                    requestCancelEditing()
                }
                .disabled(isSavingEdits)
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if isEditing {
                Button {
                    Task { await saveEdits() }
                } label: {
                    if isSavingEdits {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                    }
                }
                .disabled(isSavingEdits)
                .accessibilityLabel("common.save")
            } else {
                Menu {
                    Button("memory.edit.button") {
                        beginEditing()
                    }

                    if productPathPolicy.exposesAnalysisDebugSurfaces {
                        Divider()

                        Button(isRefreshingPipeline ? String(localized: "memory.analysis.retrying") : String(localized: "memory.analysis.retry")) {
                            Task { await refreshPipeline() }
                        }
                        .disabled(isRefreshingPipeline)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("common.more")
            }
        }
    }

    private func detailAddMenu(labelStyle: MemoryAddCardMenu.LabelStyle) -> some View {
        MemoryAddCardMenu(
            selectedPhotoItems: $selectedPhotoItems,
            labelStyle: labelStyle,
            isProcessingPhoto: isProcessingPhoto,
            includesText: true,
            includesMood: false,
            includesJournaling: false,
            includesContextRefresh: false,
            onText: {
                ensureEditingForCardMutation()
                isDraftRecordBodyCardVisible = true
            },
            onCamera: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.camera)
            },
            onAudio: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.audio)
            },
            onLink: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.link)
            },
            onMusic: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.music)
            },
            onLocation: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.location)
            },
            onTodo: {
                ensureEditingForCardMutation()
                detailSheetCoordinator.present(.todo)
            }
        )
    }

    @ViewBuilder
    private func detailSheetContent(for sheet: CaptureComposerSheet) -> some View {
        switch sheet {
        case .camera:
            UnifiedCameraCaptureView { image in
                Task { await addCameraImage(image) }
            }
            .ignoresSafeArea()
        case .audio:
            UnifiedAudioCaptureSheet { draft, _ in
                appendDraftAddedArtifact(draft.withProvenance(manualProvenance(.audioRecorder)))
            }
        case .link:
            UnifiedLinkCaptureSheet { draft in
                appendDraftAddedArtifact(draft.withProvenance(manualProvenance(.linkComposer)))
            }
        case .music:
            UnifiedMusicCaptureSheet { draft in
                appendDraftAddedArtifact(draft.withProvenance(manualProvenance(.musicPicker)))
            }
        case .location:
            LocationPickerView(initialSelection: nil) { draft in
                appendDraftAddedArtifact(draft.withProvenance(manualProvenance(.locationPicker)))
            }
        case .todo:
            UnifiedTodoCaptureSheet { draft in
                appendDraftAddedArtifact(draft.withProvenance(manualProvenance(.todoComposer)))
            }
        case .mood, .journalingFallback:
            ContentUnavailableView("capture.action.add", systemImage: "plus")
        }
    }

    @MainActor
    private func load() async {
        guard !isReloading else { return }
        isReloading = true
        defer { isReloading = false }

        do {
            snapshot = try memoryRepository.fetchMemoryDetail(recordID: recordID)
            if let snapshot {
                resetEditDraft(from: snapshot)
            }
            errorMessage = snapshot == nil ? String(localized: "memory.error.notFound") : nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshPipeline() async {
        guard !isRefreshingPipeline else { return }
        isRefreshingPipeline = true
        defer { isRefreshingPipeline = false }
        do {
            try await memoryRepository.refreshMemoryPipeline(recordID: recordID)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func prepareEditDraft() {
        if let snapshot {
            resetEditDraft(from: snapshot)
        }
    }

    private func beginEditing() {
        prepareEditDraft()
        errorMessage = nil
        isEditing = true
    }

    private func ensureEditingForCardMutation() {
        if !isEditing {
            prepareEditDraft()
            errorMessage = nil
            isEditing = true
        }
    }

    private func requestCancelEditing() {
        if draftHasChanges {
            isConfirmingDiscardEdits = true
        } else {
            discardEditDraft()
        }
    }

    private func discardEditDraft() {
        if let snapshot {
            resetEditDraft(from: snapshot)
        }
        errorMessage = nil
        isEditing = false
    }

    private func resetEditDraft(from snapshot: MemoryDetailSnapshot) {
        let record = snapshot.record
        draftTitle = record.displayTitle
        draftRawText = record.rawText
        isDraftRecordBodyCardVisible = record.rawText.trimmedOrNil != nil
        draftArtifactOrder = orderedArtifacts(from: snapshot).map(\.id)
        draftCardArrangement = editBaseArrangement(for: snapshot)
        draftDeletedArtifactIDs = []
        draftAddedArtifactDrafts = []
        draftAddedCardArrangement = MemoryCardArrangementDraft()
    }

    private var draftHasChanges: Bool {
        guard let snapshot else {
            return false
        }
        let record = snapshot.record
        if draftTitle.generatedMemoryTitle() != record.displayTitle.generatedMemoryTitle() { return true }
        if draftRawText != record.rawText { return true }
        if !draftDeletedArtifactIDs.isEmpty { return true }
        if !draftAddedArtifactDrafts.isEmpty { return true }
        if draftCardArrangement != editBaseArrangement(for: snapshot) { return true }
        return mutationArtifactOrder != nil
    }

    @MainActor
    private func saveEdits() async {
        guard !isSavingEdits else { return }
        isSavingEdits = true
        defer { isSavingEdits = false }

        do {
            let result = try await memoryRepository.applyMemoryMutation(
                recordID: recordID,
                mutation: MemoryMutationDraft(
                    recordPatch: MemoryMutationRecordPatch(
                        title: .set(draftTitle),
                        rawText: .set(draftRawText)
                    ),
                    addedArtifacts: addedArtifactsForEditedDraft(),
                    addedCardArrangement: addedCardArrangementForEditedDraft(),
                    updatedArtifacts: updatedTextArtifactsForEditedBody(),
                    deletedArtifactIDs: Array(draftDeletedArtifactIDs),
                    artifactOrder: mutationArtifactOrder,
                    cardArrangement: draftCardArrangement
                ),
                refreshPolicy: .saveOnly
            )
            snapshot = result.detail
            isEditing = false
            if let detail = result.detail {
                resetEditDraft(from: detail)
            }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var draftEditableArtifacts: [Artifact] {
        guard let snapshot else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        return draftArtifactOrder
            .filter { !draftDeletedArtifactIDs.contains($0) }
            .compactMap { artifactByID[$0] }
            .filter(\.isVisibleMemoryDetailAttachment)
    }

    private var draftAddedAttachmentItems: [CaptureComposerAttachmentItem] {
        let draftByID = Dictionary(uniqueKeysWithValues: draftAddedArtifactDrafts.map { ($0.draftID, $0) })
        let orderedNodes = draftAddedCardArrangement.nodes.sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
        return orderedNodes.flatMap { node -> [CaptureComposerAttachmentItem] in
            switch node.contentRef {
            case let .artifactDraft(draftID):
                guard let index = draftAddedArtifactDrafts.firstIndex(where: { $0.draftID == draftID }) else { return [] }
                return [.staged(index: index, draft: draftAddedArtifactDrafts[index])]
            case let .artifactDraftGroup(draftIDs, _):
                let drafts = draftIDs.compactMap { draftByID[$0] }
                guard !drafts.isEmpty else { return [] }
                if drafts.allSatisfy(\.isMemoryCardMergeableMedia),
                   let groupItem = CaptureComposerAttachmentItem.draftGroup(nodeID: node.id, drafts: drafts) {
                    return [groupItem]
                }
                return drafts.compactMap { draft in
                    guard let index = draftAddedArtifactDrafts.firstIndex(where: { $0.draftID == draft.draftID }) else { return nil }
                    return .staged(index: index, draft: draft)
                }
            case .recordBody, .affectDraft, .journalingSuggestion:
                return []
            }
        }
    }

    private var mutationArtifactOrder: [UUID]? {
        guard let snapshot else { return nil }
        let originalRemainingOrder = orderedArtifacts(from: snapshot)
            .map(\.id)
            .filter { !draftDeletedArtifactIDs.contains($0) }
        let remainingDraftOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        return remainingDraftOrder == originalRemainingOrder ? nil : remainingDraftOrder
    }

    private func updatedTextArtifactsForEditedBody() -> [Artifact] {
        guard let snapshot, draftRawText != snapshot.record.rawText else {
            return []
        }
        guard var artifact = orderedArtifacts(from: snapshot).first(where: { $0.kind == .text }) else {
            return []
        }

        let body = draftRawText.trimmedOrNil ?? ""
        artifact.title = body.generatedMemoryTitle() ?? artifact.title
        artifact.summary = body
        artifact.textContent = body
        artifact.payload = .text(body)
        return [artifact]
    }

    private func addedArtifactsForEditedDraft() -> [CaptureArtifactDraft] {
        draftAddedArtifactDrafts
    }

    private func addedCardArrangementForEditedDraft() -> MemoryCardArrangementDraft? {
        draftAddedArtifactDrafts.isEmpty ? nil : draftAddedCardArrangement
    }

    private func orderedArtifacts(from snapshot: MemoryDetailSnapshot) -> [Artifact] {
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        let ordered = snapshot.record.artifactIDs.compactMap { artifactByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let remaining = snapshot.artifacts
            .filter { !orderedIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        return ordered + remaining
    }

    private func editBaseArrangement(for snapshot: MemoryDetailSnapshot) -> MemoryCardArrangement {
        snapshot.cardArrangement
            ?? MemoryCardArrangement.defaultArrangement(
                record: snapshot.record,
                artifacts: snapshot.artifacts,
                createdAt: snapshot.record.createdAt
            )
    }

    private func stackDraftArtifactWithPrevious(_ artifactID: UUID) {
        guard let arrangement = draftCardArrangement,
              let artifact = draftEditableArtifacts.first(where: { $0.id == artifactID }),
              artifact.isMemoryCardMergeableMedia else { return }
        let nodes = arrangement.nodes.sorted { lhs, rhs in
            if lhs.layout.order == rhs.layout.order {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.layout.order < rhs.layout.order
        }
        guard let index = nodes.firstIndex(where: { $0.detailEditingArtifactIDs.contains(artifactID) }),
              index > 0 else {
            return
        }
        let previousIDs = nodes[index - 1].detailEditingArtifactIDs
        guard !previousIDs.isEmpty,
              previousIDs.allSatisfy({ previousID in
                  draftEditableArtifacts.first(where: { $0.id == previousID })?.isMemoryCardMergeableMedia == true
              }) else {
            return
        }
        applyDraftCardArrangement(arrangement.stackingWithPrevious(artifactID: artifactID, updatedAt: Date.now))
    }

    private func unstackDraftArtifact(_ artifactID: UUID) {
        guard let snapshot else { return }
        guard let arrangement = draftCardArrangement else { return }
        applyDraftCardArrangement(arrangement.unstackingContainingArtifactID(
            artifactID,
            artifacts: snapshot.artifacts,
            updatedAt: Date.now
        ))
    }

    private func setDraftCardDensity(nodeID: UUID, density: MemoryCardContentDensity) {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.18)) {
            applyDraftCardArrangement(arrangement.settingContentDensity(density, forNodeID: nodeID, updatedAt: Date.now))
        }
    }

    private func autoArrangeDraftCards() {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.22)) {
            applyDraftCardArrangement(arrangement.autoArranged(updatedAt: Date.now))
        }
    }

    private func syncDraftCardArrangement() {
        guard let snapshot, let arrangement = draftCardArrangement else { return }
        var updatedRecord = snapshot.record
        updatedRecord.rawText = draftRawText
        updatedRecord.title = draftTitle.generatedMemoryTitle()
        updatedRecord.artifactIDs = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        let artifacts = snapshot.artifacts.filter { !draftDeletedArtifactIDs.contains($0.id) }
        applyDraftCardArrangement(arrangement.synchronized(
            record: updatedRecord,
            artifacts: artifacts,
            artifactOrder: updatedRecord.artifactIDs,
            updatedAt: Date.now
        ))
    }

    private func previewRecord() {
        guard let snapshot else { return }
        do {
            previewCoordinator.clearTemporaryFiles()
            previewDeleteArtifactIDs = []
            presentPreviewURLs(try previewCoordinator.previewURLs(for: snapshot.record))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func previewArtifacts(_ ids: [UUID]) {
        guard let snapshot else { return }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        let artifacts = ids.compactMap { artifactByID[$0] }
        do {
            previewCoordinator.clearTemporaryFiles()
            previewDeleteArtifactIDs = artifacts.map(\.id)
            presentPreviewURLs(try previewCoordinator.previewURLs(for: artifacts))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func previewAddedDraftItem(_ item: CaptureComposerAttachmentItem) {
        do {
            previewCoordinator.clearTemporaryFiles()
            switch item.source {
            case let .stagedArtifact(index):
                guard draftAddedArtifactDrafts.indices.contains(index) else { return }
                previewDeleteArtifactIDs = []
                presentPreviewURLs(try previewCoordinator.previewURLs(for: [draftAddedArtifactDrafts[index]]))
            case let .draftGroup(_, draftIDs):
                let draftByID = Dictionary(uniqueKeysWithValues: draftAddedArtifactDrafts.map { ($0.draftID, $0) })
                previewDeleteArtifactIDs = []
                presentPreviewURLs(try previewCoordinator.previewURLs(for: draftIDs.compactMap { draftByID[$0] }))
            default:
                return
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentPreviewURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        previewURLs = urls
    }

    private func openPlace(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        MemoryCardExternalActions.openPlace(artifact)
    }

    private func openLink(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        MemoryCardExternalActions.openLink(artifact)
    }

    private func toggleMusic(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        Task {
            do {
                _ = try await MoryMusicPlaybackController.togglePlayback(for: artifact)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func setCardDensity(nodeID: UUID, density: MemoryCardContentDensity) {
        ensureEditingForCardMutation()
        setDraftCardDensity(nodeID: nodeID, density: density)
    }

    private func mergeMediaWithPrevious(_ artifactID: UUID) {
        guard let snapshot,
              canMergeMediaWithPrevious(artifactID: artifactID, snapshot: snapshot) else { return }
        ensureEditingForCardMutation()
        stackDraftArtifactWithPrevious(artifactID)
    }

    private func canMergeMediaWithPrevious(artifactID: UUID, snapshot: MemoryDetailSnapshot) -> Bool {
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        let nodes = MemoryDeskRenderPlan.nodes(for: snapshot)
        guard let index = nodes.firstIndex(where: { $0.contentRef.artifactIDs.contains(artifactID) }),
              index > 0 else {
            return false
        }
        let currentIDs = nodes[index].contentRef.artifactIDs
        let previousIDs = nodes[index - 1].contentRef.artifactIDs
        guard currentIDs.count == 1,
              currentIDs[0] == artifactID,
              artifactByID[artifactID]?.isMemoryCardMergeableMedia == true,
              !previousIDs.isEmpty else {
            return false
        }
        return previousIDs.allSatisfy { artifactByID[$0]?.isMemoryCardMergeableMedia == true }
    }

    private func unmergeMedia(nodeID: UUID) {
        ensureEditingForCardMutation()
        guard let snapshot, let arrangement = draftCardArrangement else { return }
        applyDraftCardArrangement(arrangement.unstacking(nodeID: nodeID, artifacts: snapshot.artifacts, updatedAt: Date.now))
    }

    private func requestDeleteArtifacts(_ ids: [UUID]) {
        pendingDeleteArtifactIDs = ids
        isConfirmingCardDeletion = !ids.isEmpty
    }

    private func confirmPendingCardDeletion() {
        let ids = pendingDeleteArtifactIDs
        pendingDeleteArtifactIDs = []
        guard !ids.isEmpty else { return }
        stageDeleteArtifacts(ids)
    }

    private func stageDeleteArtifacts(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        ensureEditingForCardMutation()
        withAnimation(.snappy(duration: 0.2)) {
            draftDeletedArtifactIDs.formUnion(ids)
            syncDraftCardArrangement()
        }
    }

    @MainActor
    private func appendDraftAddedArtifact(_ draft: CaptureArtifactDraft) {
        ensureEditingForCardMutation()
        draftAddedArtifactDrafts.append(draft)
        draftAddedCardArrangement.appendArtifactDraft(draft)
    }

    @MainActor
    private func addPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        ensureEditingForCardMutation()
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
                appendDraftAddedArtifact(draft)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func addCameraImage(_ image: UIImage) async {
        guard let data = image.jpegData(compressionQuality: 0.86) else { return }
        ensureEditingForCardMutation()
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        await addPhotoData(data, filename: "camera_\(Int(Date().timeIntervalSince1970)).jpg")
    }

    @MainActor
    private func addPhotoData(_ data: Data, filename: String) async {
        let result = await PhotoArtifactProcessor().process(imageData: data, filename: filename)
        let summary = result.summary.trimmedOrNil ?? String(localized: "quickCapture.photo.defaultSummary")
        appendDraftAddedArtifact(.photo(
            title: nil,
            summary: summary,
            filename: filename,
            imageData: data,
            thumbnailData: result.thumbnailData,
            ocrText: result.ocrText,
            photoMetadata: result.metadata,
            origin: .manual,
            provenance: manualProvenance(.camera)
        ))
    }

    @MainActor
    private func removeAddedDraft(at index: Int) {
        guard draftAddedArtifactDrafts.indices.contains(index) else { return }
        let removed = draftAddedArtifactDrafts.remove(at: index)
        draftAddedCardArrangement.removeArtifactDraft(removed.draftID, artifactDrafts: draftAddedArtifactDrafts)
    }

    @MainActor
    private func removeAddedDraftGroup(_ draftIDs: [UUID]) {
        guard !draftIDs.isEmpty else { return }
        let ids = Set(draftIDs)
        draftAddedArtifactDrafts.removeAll { ids.contains($0.draftID) }
        draftIDs.forEach { draftAddedCardArrangement.removeArtifactDraft($0, artifactDrafts: draftAddedArtifactDrafts) }
    }

    @MainActor
    private func setAddedDraftDensity(item: CaptureComposerAttachmentItem, density: MemoryCardContentDensity) {
        guard let draftID = addedDraftID(for: item) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            draftAddedCardArrangement.setContentDensity(density, forDraftID: draftID)
        }
    }

    @MainActor
    private func reorderAddedDraftItem(from source: CaptureComposerAttachmentItem, to target: CaptureComposerAttachmentItem) {
        guard let sourceDraftID = addedDraftID(for: source),
              let targetDraftID = addedDraftID(for: target),
              sourceDraftID != targetDraftID else {
            return
        }
        withAnimation(.snappy(duration: 0.2)) {
            draftAddedCardArrangement.reorderArtifactDraft(from: sourceDraftID, to: targetDraftID)
        }
    }

    @MainActor
    private func stackAddedDraftWithPrevious(item: CaptureComposerAttachmentItem) {
        guard let draftID = addedDraftID(for: item) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            draftAddedCardArrangement.toggleStackWithPrevious(draftID: draftID)
        }
    }

    @MainActor
    private func unstackAddedDraft(item: CaptureComposerAttachmentItem) {
        guard let draftID = addedDraftID(for: item) else { return }
        withAnimation(.snappy(duration: 0.18)) {
            draftAddedCardArrangement.unstackContainingDraft(draftID, artifactDrafts: draftAddedArtifactDrafts)
        }
    }

    private func addedDraftID(for item: CaptureComposerAttachmentItem) -> UUID? {
        switch item.source {
        case let .stagedArtifact(index):
            return draftAddedArtifactDrafts.indices.contains(index) ? draftAddedArtifactDrafts[index].draftID : nil
        case let .draftGroup(_, draftIDs):
            return draftIDs.first
        case .contextCandidate, .affect, .journalingSuggestion, .processing:
            return nil
        }
    }

    private func manualProvenance(_ sourceKind: CaptureProvenanceSourceKind) -> CaptureProvenance {
        CaptureProvenance(originCategory: .userInput, sourceKind: sourceKind)
    }

    private func applyDraftCardArrangement(_ arrangement: MemoryCardArrangement) {
        draftCardArrangement = arrangement
        syncDraftArtifactOrder(with: arrangement)
    }

    private func syncDraftArtifactOrder(with arrangement: MemoryCardArrangement) {
        let arrangedIDs = arrangement.nodes
            .sorted { lhs, rhs in
                if lhs.layout.order == rhs.layout.order {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.layout.order < rhs.layout.order
            }
            .flatMap(\.detailEditingArtifactIDs)
        let arrangedSet = Set(arrangedIDs)
        let remainingIDs = draftArtifactOrder.filter { !arrangedSet.contains($0) }
        draftArtifactOrder = arrangedIDs + remainingIDs
    }

    private var visibleDraftAttachmentIDs: [UUID] {
        guard let snapshot else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        return draftArtifactOrder
            .filter { !draftDeletedArtifactIDs.contains($0) }
            .filter { artifactByID[$0]?.isVisibleMemoryDetailAttachment == true }
    }

}

private struct MemoryDetailEditingView: View {
    @Binding var title: String
    @Binding var rawText: String
    @Binding var isRecordBodyCardVisible: Bool

    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    let addedDraftItems: [CaptureComposerAttachmentItem]
    let errorMessage: String?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onPreviewArtifacts: ([UUID]) -> Void
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void
    var onStackArtifactWithPrevious: (UUID) -> Void
    var onUnstackArtifact: (UUID) -> Void
    var onAutoArrange: () -> Void
    var onRemoveAddedDraft: (Int) -> Void
    var onRemoveAddedDraftGroup: ([UUID]) -> Void
    var onPreviewAddedDraft: (CaptureComposerAttachmentItem) -> Void
    var onSetAddedDraftDensity: (CaptureComposerAttachmentItem, MemoryCardContentDensity) -> Void
    var onReorderAddedDraft: (CaptureComposerAttachmentItem, CaptureComposerAttachmentItem) -> Void
    var onStackAddedDraftWithPrevious: (CaptureComposerAttachmentItem) -> Void
    var onUnstackAddedDraft: (CaptureComposerAttachmentItem) -> Void

    @FocusState private var isBodyFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    MemoryDetailEditingBoardView(
                        artifacts: artifacts,
                        cardArrangement: cardArrangement,
                        onDeleteArtifacts: onDeleteArtifacts,
                        onPreviewArtifacts: onPreviewArtifacts,
                        onSetCardDensity: onSetCardDensity,
                        onStackArtifactWithPrevious: onStackArtifactWithPrevious,
                        onUnstackArtifact: onUnstackArtifact,
                        onAutoArrange: onAutoArrange
                    )

                    if !addedDraftItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("memory.edit.newCards")
                                .font(.headline)
                                .padding(.horizontal, 20)

                            CaptureAttachmentCompactBoardView(
                                items: addedDraftItems,
                                onRemoveStagedArtifact: onRemoveAddedDraft,
                                onRemoveContextCandidate: { _ in },
                                onRemoveDraftGroup: onRemoveAddedDraftGroup,
                                onRemoveAffectDraft: { _ in },
                                onRemoveJournalingSuggestion: { _ in },
                                onReorderItems: onReorderAddedDraft,
                                onStackWithPrevious: onStackAddedDraftWithPrevious,
                                onUnstack: onUnstackAddedDraft,
                                onSetDensity: onSetAddedDraftDensity,
                                onPreview: onPreviewAddedDraft
                            )
                        }
                        .padding(.top, artifacts.isEmpty ? 16 : 10)
                    }

                    titleEditor
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if isRecordBodyCardVisible {
                        RecordBodyCardEditor(
                            text: $rawText,
                            focus: $isBodyFocused,
                            minHeight: max(proxy.size.height - 360, 160)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }

                    statusSection
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Color(.systemBackground))
    }

    private var titleEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memory.edit.title")
                .font(.headline)
            TextField("memory.edit.title.placeholder", text: $title)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusSection: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

}

private struct MemoryDetailEditingBoardView: View {
    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onPreviewArtifacts: ([UUID]) -> Void
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void
    var onStackArtifactWithPrevious: (UUID) -> Void
    var onUnstackArtifact: (UUID) -> Void
    var onAutoArrange: () -> Void

    @State private var measuredContainerWidth: CGFloat = 0
    private let metrics = MemoryDeskBoardMetrics.default

    private var containerWidth: CGFloat {
        measuredContainerWidth > 0 ? measuredContainerWidth : 390
    }

    private var boardNodes: [MemoryDetailEditingBoardNode] {
        guard let cardArrangement else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: artifacts.map { ($0.id, $0) })
        return cardArrangement.nodes
            .sorted { lhs, rhs in
                if lhs.layout.order == rhs.layout.order {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.layout.order < rhs.layout.order
            }
            .compactMap { node in
                MemoryDetailEditingBoardNode(node: node, artifactByID: artifactByID)
            }
    }

    private var layoutPlan: MemoryDeskBoardLayoutPlan<UUID> {
        let columnWidth = metrics.columnSpec(for: containerWidth).columnWidth
        return MemoryDeskBoardLayoutPlan.make(
            nodes: boardNodes.map {
                MemoryDeskBoardInputNode(
                    id: $0.id,
                    layout: $0.layout,
                    estimatedHeight: MemoryCardObjectMetrics.estimatedHeight(
                        for: $0.contentKind,
                        density: $0.contentDensity,
                        columnWidth: columnWidth,
                        mediaAspectRatio: $0.item.payload.mediaAspectRatio
                    )
                )
            },
            containerWidth: containerWidth,
            metrics: metrics
        )
    }

    private var resolvedSlots: [MemoryDetailEditingBoardSlot] {
        let nodeByID = Dictionary(uniqueKeysWithValues: boardNodes.map { ($0.id, $0) })
        return layoutPlan.slots.compactMap { slot in
            guard let node = nodeByID[slot.id] else { return nil }
            return MemoryDetailEditingBoardSlot(node: node, frame: slot.frame)
        }
    }

    var body: some View {
        if !boardNodes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Arrangement")
                        .font(.headline)
                    Spacer()
                    Button {
                        onAutoArrange()
                    } label: {
                        Label("Auto Arrange", systemImage: "wand.and.stars")
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ZStack(alignment: .topLeading) {
                    ForEach(resolvedSlots) { slot in
                        MemoryDetailEditingBoardCard(
                            node: slot.node,
                            availableSize: slot.frame.size,
                            canMergeWithPrevious: canMergeMediaWithPrevious(slot.node),
                            onDelete: { onDeleteArtifacts(slot.node.artifactIDs) },
                            onPreview: { onPreviewArtifacts(slot.node.artifactIDs) },
                            onSetDensity: { density in onSetCardDensity(slot.node.id, density) },
                            onStackWithPrevious: { onStackArtifactWithPrevious(slot.node.primaryArtifactID) },
                            onUnstack: { onUnstackArtifact(slot.node.primaryArtifactID) }
                        )
                        .frame(width: slot.frame.width, height: slot.frame.height, alignment: .center)
                        .position(
                            x: slot.frame.midX + slot.node.layout.xNudge,
                            y: slot.frame.midY + slot.node.layout.yNudge
                        )
                        .rotationEffect(.degrees(slot.node.renderRotationDegrees))
                        .zIndex(slot.node.layout.renderZIndex)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: layoutPlan.boardHeight, maxHeight: layoutPlan.boardHeight, alignment: .topLeading)
                .background(boardBackground)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                updateMeasuredWidth(proxy.size.width)
                            }
                            .onChange(of: proxy.size.width) { _, newWidth in
                                updateMeasuredWidth(newWidth)
                            }
                    }
                }
            }
        }
    }

    private var boardBackground: some View {
        LinearGradient(
            colors: [
                Color(.secondarySystemBackground).opacity(0.34),
                Color(.systemBackground).opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func updateMeasuredWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0, abs(width - measuredContainerWidth) > 0.5 else { return }
        measuredContainerWidth = width
    }

    private func canMergeMediaWithPrevious(_ node: MemoryDetailEditingBoardNode) -> Bool {
        guard node.isSingleMedia else { return false }
        guard let index = boardNodes.firstIndex(where: { $0.id == node.id }), index > 0 else { return false }
        return boardNodes[index - 1].isMediaNode
    }

}

private struct MemoryDetailEditingBoardCard: View {
    let node: MemoryDetailEditingBoardNode
    let availableSize: CGSize
    let canMergeWithPrevious: Bool
    var onDelete: () -> Void
    var onPreview: () -> Void
    var onSetDensity: (MemoryCardContentDensity) -> Void
    var onStackWithPrevious: () -> Void
    var onUnstack: () -> Void

    var body: some View {
        CaptureCardView(
            presentation: CaptureCardPresentation(
                item: node.item,
                role: .detailEditing,
                provenanceDisplayMode: .production,
                contentKind: node.contentKind,
                contentDensity: node.contentDensity
            ),
            objectAvailableSize: availableSize,
            onTap: onPreview
        )
        .contextMenu {
            MemoryCardActionMenu(configuration: MemoryCardActionMenuConfiguration(
                contentKind: node.contentKind,
                contentDensity: node.contentDensity,
                canPreview: true,
                canEdit: false,
                canSetDensity: true,
                canMergeMedia: canMergeWithPrevious,
                canSpreadMedia: node.isMediaGroup,
                canDelete: true,
                onPreview: onPreview,
                onSetDensity: onSetDensity,
                onMergeMedia: onStackWithPrevious,
                onSpreadMedia: onUnstack,
                onDelete: onDelete
            ))
        }
    }
}

private struct MemoryDetailEditingBoardNode: Identifiable {
    let id: UUID
    let artifactIDs: [UUID]
    let artifacts: [Artifact]
    let item: CaptureCardItem
    let contentKind: MemoryCardContentKind
    let contentDensity: MemoryCardContentDensity
    let layout: MemoryCardLayoutToken

    var primaryArtifactID: UUID {
        artifactIDs[0]
    }

    init?(node: MemoryCardNode, artifactByID: [UUID: Artifact]) {
        let artifacts: [Artifact]
        switch node.contentRef {
        case let .artifact(id):
            guard let artifact = artifactByID[id] else { return nil }
            artifacts = [artifact]
        case let .artifactGroup(ids, _):
            artifacts = ids.compactMap { artifactByID[$0] }
            guard !artifacts.isEmpty else { return nil }
        case .recordBody, .affect, .journalingSuggestion:
            return nil
        }

        self.id = node.id
        self.artifactIDs = artifacts.map(\.id)
        self.artifacts = artifacts
        self.item = artifacts.count == 1
            ? CaptureCardItem(artifact: artifacts[0])
            : Self.groupItem(nodeID: node.id, artifacts: artifacts)
        self.contentKind = Self.contentKind(for: artifacts)
        self.contentDensity = node.contentDensity
        self.layout = node.layout
    }

    private static func groupItem(nodeID: UUID, artifacts: [Artifact]) -> CaptureCardItem {
        if let first = artifacts.first,
           first.isMemoryCardMergeableMedia,
           artifacts.allSatisfy(\.isMemoryCardMergeableMedia) {
            return mediaStackItem(nodeID: nodeID, first: first, artifacts: artifacts)
        }

        let thumbnail = artifacts.compactMap { $0.previewPayload ?? $0.binaryPayload }.first
        return CaptureCardItem(
            id: "edit-group-\(nodeID.uuidString)",
            payload: .journalingSuggestion(
                CaptureJournalingSuggestionCardPayload(
                    artifactCount: artifacts.count,
                    affectCount: 0,
                    photoCount: artifacts.filter { $0.kind == .photo }.count,
                    videoCount: artifacts.filter { $0.kind == .video }.count,
                    livePhotoCount: artifacts.filter { $0.kind == .livePhoto }.count,
                    locationCount: artifacts.filter { $0.kind == .location }.count,
                    musicCount: artifacts.filter { $0.kind == .music }.count,
                    promptCount: artifacts.filter { $0.metadata["documentType"] == "promptAnswer" }.count,
                    thumbnailData: thumbnail
                )
            ),
            origin: artifacts.first?.captureProvenance?.artifactOrigin,
            provenance: artifacts.first?.captureProvenance,
            title: "Stack",
            detail: artifacts.map(\.title).compactMap(\.trimmedOrNil).prefix(3).joined(separator: " · "),
            metadata: "\(artifacts.count)"
        )
    }

    private static func mediaStackItem(nodeID: UUID, first: Artifact, artifacts: [Artifact]) -> CaptureCardItem {
        let base = CaptureCardItem(artifact: first)
        let payload: CaptureCardPayload
        switch base.payload {
        case var .photo(photo):
            photo.photoCount = artifacts.count
            payload = .photo(photo)
        case var .video(video):
            video.mediaCount = artifacts.count
            payload = .video(video)
        case var .livePhoto(livePhoto):
            livePhoto.mediaCount = artifacts.count
            payload = .livePhoto(livePhoto)
        default:
            payload = base.payload
        }
        return CaptureCardItem(
            id: "edit-media-group-\(nodeID.uuidString)",
            payload: payload,
            origin: first.captureProvenance?.artifactOrigin,
            provenance: first.captureProvenance,
            title: base.title,
            detail: base.detail,
            metadata: "\(artifacts.count)"
        )
    }

    private static func contentKind(for artifacts: [Artifact]) -> MemoryCardContentKind {
        guard let first = artifacts.first else { return .bundle }
        if artifacts.count == 1 {
            return CaptureCardItem(artifact: first).memoryContentKind
        }
        guard artifacts.allSatisfy(\.isMemoryCardMergeableMedia) else {
            return .bundle
        }
        return CaptureCardItem(artifact: first).memoryContentKind
    }

    var isSingleMedia: Bool {
        artifacts.count == 1 && artifacts[0].isMemoryCardMergeableMedia
    }

    var isMediaNode: Bool {
        !artifacts.isEmpty && artifacts.allSatisfy(\.isMemoryCardMergeableMedia)
    }

    var isMediaGroup: Bool {
        artifacts.count > 1 && isMediaNode
    }

    var renderRotationDegrees: Double {
        isMediaNode ? 0 : layout.rotationDegrees
    }
}

private struct MemoryDetailEditingBoardSlot: Identifiable {
    let id: UUID
    let node: MemoryDetailEditingBoardNode
    let frame: CGRect

    init(node: MemoryDetailEditingBoardNode, frame: CGRect) {
        self.id = node.id
        self.node = node
        self.frame = frame
    }
}

private extension Artifact {
    var isVisibleMemoryDetailAttachment: Bool {
        kind != .text
    }
}

private extension MemoryCardNode {
    var detailEditingArtifactIDs: [UUID] {
        switch contentRef {
        case let .artifact(id):
            return [id]
        case let .artifactGroup(ids, _):
            return ids
        case .recordBody, .affect, .journalingSuggestion:
            return []
        }
    }
}

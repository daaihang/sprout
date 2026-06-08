import PhotosUI
import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) var memoryRepository

    let recordID: UUID

    @State var snapshot: MemoryDetailSnapshot?
    @State var errorMessage: String?
    @State var isRefreshingPipeline = false
    @State var isReloading = false
    @State var isEditing = false
    @State var draftTitle = ""
    @State var draftRawText = ""
    @State var isDraftRecordBodyCardVisible = false
    @State var draftArtifactOrder: [UUID] = []
    @State var draftCardArrangement: MemoryCardArrangement?
    @State var draftDeletedArtifactIDs: Set<UUID> = []
    @State var draftAddedArtifactDrafts: [CaptureArtifactDraft] = []
    @State var draftAddedCardArrangement = MemoryCardArrangementDraft()
    @State var selectedPhotoItems: [PhotosPickerItem] = []
    @State var detailSheetCoordinator = CaptureComposerSheetCoordinator()
    @State var isProcessingPhoto = false
    @State var isSavingEdits = false
    @State var isConfirmingDiscardEdits = false
    @State var previewCoordinator = MemoryCardPreviewCoordinator()
    @State var previewURLs: [URL] = []
    @State var previewDeleteArtifactIDs: [UUID] = []
    @State var pendingDeleteArtifactIDs: [UUID] = []
    @State var isConfirmingCardDeletion = false

    let productPathPolicy = MemoryDetailProductPathPolicy()

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
    func detailToolbar() -> some ToolbarContent {
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

    @MainActor
    func load() async {
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

    func refreshPipeline() async {
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

    func previewRecord() {
        guard let snapshot else { return }
        do {
            previewCoordinator.clearTemporaryFiles()
            previewDeleteArtifactIDs = []
            presentPreviewURLs(try previewCoordinator.previewURLs(for: snapshot.record))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previewArtifacts(_ ids: [UUID]) {
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

    func previewAddedDraftItem(_ item: CaptureComposerAttachmentItem) {
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

    func presentPreviewURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        previewURLs = urls
    }

    func openPlace(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        MemoryCardExternalActions.openPlace(artifact)
    }

    func openLink(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        MemoryCardExternalActions.openLink(artifact)
    }

    func toggleMusic(_ artifactID: UUID) {
        guard let artifact = snapshot?.artifacts.first(where: { $0.id == artifactID }) else { return }
        Task {
            do {
                _ = try await MoryMusicPlaybackController.togglePlayback(for: artifact)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setCardDensity(nodeID: UUID, density: MemoryCardContentDensity) {
        ensureEditingForCardMutation()
        setDraftCardDensity(nodeID: nodeID, density: density)
    }

    func mergeMediaWithPrevious(_ artifactID: UUID) {
        guard let snapshot,
              canMergeMediaWithPrevious(artifactID: artifactID, snapshot: snapshot) else { return }
        ensureEditingForCardMutation()
        stackDraftArtifactWithPrevious(artifactID)
    }

    func canMergeMediaWithPrevious(artifactID: UUID, snapshot: MemoryDetailSnapshot) -> Bool {
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

    func unmergeMedia(nodeID: UUID) {
        ensureEditingForCardMutation()
        guard let snapshot, let arrangement = draftCardArrangement else { return }
        applyDraftCardArrangement(arrangement.unstacking(nodeID: nodeID, artifacts: snapshot.artifacts, updatedAt: Date.now))
    }

    func requestDeleteArtifacts(_ ids: [UUID]) {
        pendingDeleteArtifactIDs = ids
        isConfirmingCardDeletion = !ids.isEmpty
    }

    func confirmPendingCardDeletion() {
        let ids = pendingDeleteArtifactIDs
        pendingDeleteArtifactIDs = []
        guard !ids.isEmpty else { return }
        stageDeleteArtifacts(ids)
    }

    func stageDeleteArtifacts(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        ensureEditingForCardMutation()
        withAnimation(.snappy(duration: 0.2)) {
            draftDeletedArtifactIDs.formUnion(ids)
            syncDraftCardArrangement()
        }
    }

}

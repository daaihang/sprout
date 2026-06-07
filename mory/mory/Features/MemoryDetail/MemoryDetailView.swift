import QuickLook
import SwiftUI

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
    @State private var draftArtifactOrder: [UUID] = []
    @State private var draftCardArrangement: MemoryCardArrangement?
    @State private var draftDeletedArtifactIDs: Set<UUID> = []
    @State private var draftNewArtifactKind: MemoryDetailNewArtifactKind = .note
    @State private var draftNewArtifactID = UUID()
    @State private var draftNewArtifactTitle = ""
    @State private var draftNewArtifactURL = ""
    @State private var draftNewArtifactText = ""
    @State private var isSavingEdits = false
    @State private var isConfirmingDiscardEdits = false
    @State private var previewCoordinator = MemoryCardPreviewCoordinator()
    @State private var previewURL: URL?
    @State private var previewURLs: [URL] = []
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
                        newArtifactKind: $draftNewArtifactKind,
                        newArtifactTitle: $draftNewArtifactTitle,
                        newArtifactURL: $draftNewArtifactURL,
                        newArtifactText: $draftNewArtifactText,
                        artifacts: draftEditableArtifacts,
                        cardArrangement: draftCardArrangement,
                        errorMessage: errorMessage,
                        onDeleteArtifacts: { artifactIDs in
                            withAnimation(.snappy(duration: 0.2)) {
                                draftDeletedArtifactIDs.formUnion(artifactIDs)
                                syncDraftCardArrangement()
                            }
                        },
                        onPreviewArtifacts: previewArtifacts(_:),
                        onSetCardDensity: setDraftCardDensity(nodeID:density:),
                        onMoveArtifact: moveDraftArtifact(_:by:),
                        onStackArtifactWithPrevious: stackDraftArtifactWithPrevious(_:),
                        onUnstackArtifact: unstackDraftArtifact(_:),
                        onAutoArrange: autoArrangeDraftCards
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
                Task { await deletePendingArtifacts() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("memory.card.delete.message")
        }
        .quickLookPreview($previewURL, in: previewURLs)
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
                Button(isSavingEdits ? String(localized: "common.saving") : String(localized: "memory.edit.done")) {
                    Task { await saveEdits() }
                }
                .disabled(isSavingEdits || draftRawText.trimmedOrNil == nil)
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
        draftArtifactOrder = orderedArtifacts(from: snapshot).map(\.id)
        draftCardArrangement = editBaseArrangement(for: snapshot)
        draftDeletedArtifactIDs = []
        draftNewArtifactKind = .note
        draftNewArtifactID = UUID()
        draftNewArtifactTitle = ""
        draftNewArtifactURL = ""
        draftNewArtifactText = ""
    }

    private var draftHasChanges: Bool {
        guard let snapshot else {
            return false
        }
        let record = snapshot.record
        if draftTitle.generatedMemoryTitle() != record.displayTitle.generatedMemoryTitle() { return true }
        if draftRawText != record.rawText { return true }
        if !draftDeletedArtifactIDs.isEmpty { return true }
        if pendingNewArtifactDraft() != nil { return true }
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
        pendingNewArtifactDraft().map { [$0] } ?? []
    }

    private func addedCardArrangementForEditedDraft() -> MemoryCardArrangementDraft? {
        guard let draft = pendingNewArtifactDraft() else { return nil }
        var arrangement = MemoryCardArrangementDraft()
        arrangement.appendArtifactDraft(draft)
        return arrangement
    }

    private func pendingNewArtifactDraft() -> CaptureArtifactDraft? {
        switch draftNewArtifactKind {
        case .note:
            guard let note = draftNewArtifactText.trimmedOrNil else { return nil }
            return CaptureArtifactDraft(
                draftID: draftNewArtifactID,
                origin: .manual,
                provenance: .manualComposer,
                content: .promptAnswer(
                    PromptAnswerArtifactContent(
                        prompt: String(localized: "memory.edit.addAttachment"),
                        answer: note,
                        source: "detail_edit"
                    )
                )
            )
        case .link:
            guard let url = draftNewArtifactURL.trimmedOrNil else { return nil }
            return CaptureArtifactDraft(
                draftID: draftNewArtifactID,
                origin: .manual,
                provenance: .manualComposer,
                content: .link(
                    LinkArtifactContent(
                        title: draftNewArtifactTitle.trimmedOrNil,
                        url: url,
                        note: draftNewArtifactText.trimmedOrNil,
                        summary: draftNewArtifactText.trimmedOrNil
                    )
                )
            )
        case .todo:
            guard let title = draftNewArtifactTitle.trimmedOrNil
                ?? draftNewArtifactText.firstMeaningfulLine else {
                return nil
            }
            return CaptureArtifactDraft(
                draftID: draftNewArtifactID,
                origin: .manual,
                provenance: .manualComposer,
                content: .todo(
                    TodoArtifactContent(
                        title: title,
                        note: draftNewArtifactText.trimmedOrNil
                    )
                )
            )
        }
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

    private func canMoveDraftArtifact(_ id: UUID, by offset: Int) -> Bool {
        let visibleOrder = visibleDraftAttachmentIDs
        guard let visibleIndex = visibleOrder.firstIndex(of: id) else { return false }
        let targetIndex = visibleIndex + offset
        return visibleOrder.indices.contains(targetIndex)
    }

    private func moveDraftArtifact(_ id: UUID, by offset: Int) {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.18)) {
            applyDraftCardArrangement(arrangement.movingArtifact(artifactID: id, by: offset, updatedAt: Date.now))
        }
    }

    private func reorderDraftArtifact(_ sourceID: UUID, near targetID: UUID) {
        guard sourceID != targetID else { return }
        let visibleOrder = visibleDraftAttachmentIDs
        guard let sourceVisibleIndex = visibleOrder.firstIndex(of: sourceID),
              let targetVisibleIndex = visibleOrder.firstIndex(of: targetID),
              let sourceIndex = draftArtifactOrder.firstIndex(of: sourceID),
              let targetIndex = draftArtifactOrder.firstIndex(of: targetID) else {
            return
        }

        withAnimation(.snappy(duration: 0.2)) {
            let movedID = draftArtifactOrder.remove(at: sourceIndex)
            let adjustedTargetIndex = draftArtifactOrder.firstIndex(of: targetID) ?? targetIndex
            let insertionIndex = sourceVisibleIndex < targetVisibleIndex
                ? min(adjustedTargetIndex + 1, draftArtifactOrder.endIndex)
                : adjustedTargetIndex
            draftArtifactOrder.insert(movedID, at: insertionIndex)
            syncDraftCardArrangement()
        }
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
            presentPreviewURLs(try previewCoordinator.previewURLs(for: artifacts))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentPreviewURLs(_ urls: [URL]) {
        guard let first = urls.first else { return }
        previewURLs = urls
        previewURL = first
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
        guard let snapshot else { return }
        let arrangement = editBaseArrangement(for: snapshot)
            .settingContentDensity(density, forNodeID: nodeID, updatedAt: Date.now)
        Task { await saveCardArrangement(arrangement) }
    }

    private func mergeMediaWithPrevious(_ artifactID: UUID) {
        guard let snapshot,
              canMergeMediaWithPrevious(artifactID: artifactID, snapshot: snapshot) else { return }
        let arrangement = editBaseArrangement(for: snapshot)
            .stackingWithPrevious(artifactID: artifactID, updatedAt: Date.now)
        Task { await saveCardArrangement(arrangement) }
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
        guard let snapshot else { return }
        let arrangement = editBaseArrangement(for: snapshot)
            .unstacking(nodeID: nodeID, artifacts: snapshot.artifacts, updatedAt: Date.now)
        Task { await saveCardArrangement(arrangement) }
    }

    private func requestDeleteArtifacts(_ ids: [UUID]) {
        pendingDeleteArtifactIDs = ids
        isConfirmingCardDeletion = !ids.isEmpty
    }

    private func deletePendingArtifacts() async {
        let ids = pendingDeleteArtifactIDs
        pendingDeleteArtifactIDs = []
        guard !ids.isEmpty else { return }
        do {
            let result = try await memoryRepository.applyMemoryMutation(
                recordID: recordID,
                mutation: MemoryMutationDraft(deletedArtifactIDs: ids),
                refreshPolicy: .saveOnly
            )
            snapshot = result.detail
            if let detail = result.detail {
                resetEditDraft(from: detail)
            }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
    }

    private func saveCardArrangement(_ arrangement: MemoryCardArrangement) async {
        do {
            let result = try await memoryRepository.applyMemoryMutation(
                recordID: recordID,
                mutation: MemoryMutationDraft(cardArrangement: arrangement),
                refreshPolicy: .saveOnly
            )
            snapshot = result.detail
            if let detail = result.detail {
                resetEditDraft(from: detail)
            }
            errorMessage = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
            await load()
        }
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
    @Binding var newArtifactKind: MemoryDetailNewArtifactKind
    @Binding var newArtifactTitle: String
    @Binding var newArtifactURL: String
    @Binding var newArtifactText: String

    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    let errorMessage: String?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onPreviewArtifacts: ([UUID]) -> Void
    var onSetCardDensity: (UUID, MemoryCardContentDensity) -> Void
    var onMoveArtifact: (UUID, Int) -> Void
    var onStackArtifactWithPrevious: (UUID) -> Void
    var onUnstackArtifact: (UUID) -> Void
    var onAutoArrange: () -> Void

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
                        onMoveArtifact: onMoveArtifact,
                        onStackArtifactWithPrevious: onStackArtifactWithPrevious,
                        onUnstackArtifact: onUnstackArtifact,
                        onAutoArrange: onAutoArrange
                    )

                    supportingArtifactEditor
                        .padding(.horizontal, 20)
                        .padding(.top, artifacts.isEmpty ? 16 : 4)

                    titleEditor
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    CaptureBodyEditorView(
                        text: $rawText,
                        focus: $isBodyFocused,
                        minHeight: max(proxy.size.height - (artifacts.isEmpty ? 0 : 132), 360)
                    )

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

    private var supportingArtifactEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memory.edit.addAttachment")
                .font(.headline)

            Picker("memory.edit.addAttachment", selection: $newArtifactKind) {
                ForEach(MemoryDetailNewArtifactKind.allCases) { kind in
                    Text(kind.labelKey).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if newArtifactKind.usesTitleField {
                TextField("capture.field.title", text: $newArtifactTitle)
                    .textFieldStyle(.roundedBorder)
            }

            if newArtifactKind == .link {
                TextField("capture.field.url", text: $newArtifactURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
            }

            TextField(newArtifactKind.notePlaceholderKey, text: $newArtifactText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    var onMoveArtifact: (UUID, Int) -> Void
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
                            canMoveEarlier: canMove(slot.node, by: -1),
                            canMoveLater: canMove(slot.node, by: 1),
                            canMergeWithPrevious: canMergeMediaWithPrevious(slot.node),
                            onDelete: { onDeleteArtifacts(slot.node.artifactIDs) },
                            onPreview: { onPreviewArtifacts(slot.node.artifactIDs) },
                            onSetDensity: { density in onSetCardDensity(slot.node.id, density) },
                            onMoveEarlier: { onMoveArtifact(slot.node.primaryArtifactID, -1) },
                            onMoveLater: { onMoveArtifact(slot.node.primaryArtifactID, 1) },
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

    private func canMove(_ node: MemoryDetailEditingBoardNode, by offset: Int) -> Bool {
        guard let index = boardNodes.firstIndex(where: { $0.id == node.id }) else { return false }
        return boardNodes.indices.contains(index + offset)
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
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let canMergeWithPrevious: Bool
    var onDelete: () -> Void
    var onPreview: () -> Void
    var onSetDensity: (MemoryCardContentDensity) -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void
    var onStackWithPrevious: () -> Void
    var onUnstack: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            Menu {
                Button {
                    onPreview()
                } label: {
                    Label("memory.card.preview", systemImage: "eye")
                }

                Menu {
                    ForEach(MemoryCardPresentationPolicy.supportedDensities(for: node.contentKind)) { density in
                        Button {
                            onSetDensity(density)
                        } label: {
                            Label(density.menuLabel, systemImage: density == node.contentDensity ? "checkmark" : density.systemImage)
                        }
                    }
                } label: {
                    Label("memory.card.displayDensity", systemImage: "rectangle.3.group")
                }

                Divider()

                Button {
                    onMoveEarlier()
                } label: {
                    Label("memory.edit.moveAttachmentUp", systemImage: "arrow.up")
                }
                .disabled(!canMoveEarlier)

                Button {
                    onMoveLater()
                } label: {
                    Label("memory.edit.moveAttachmentDown", systemImage: "arrow.down")
                }
                .disabled(!canMoveLater)

                Divider()

                if canMergeWithPrevious {
                    Button {
                        onStackWithPrevious()
                    } label: {
                        Label("memory.card.mergeMedia", systemImage: "rectangle.stack.badge.plus")
                    }
                }

                if node.isMediaGroup {
                    Button {
                        onUnstack()
                    } label: {
                        Label("memory.card.spreadMedia", systemImage: "square.split.2x1")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("common.delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(9)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("common.more")
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

private enum MemoryDetailNewArtifactKind: String, CaseIterable, Identifiable {
    case note
    case link
    case todo

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .note:
            return "capture.field.note"
        case .link:
            return "capture.card.kind.link"
        case .todo:
            return "capture.card.kind.todo"
        }
    }

    var notePlaceholderKey: LocalizedStringKey {
        switch self {
        case .note:
            return "memory.edit.addAttachment.placeholder"
        case .link:
            return "capture.field.note"
        case .todo:
            return "capture.field.note"
        }
    }

    var usesTitleField: Bool {
        switch self {
        case .note:
            return false
        case .link, .todo:
            return true
        }
    }
}

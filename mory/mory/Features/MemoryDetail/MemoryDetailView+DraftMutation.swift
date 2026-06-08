import SwiftUI

extension MemoryDetailView {
    func prepareEditDraft() {
        if let snapshot {
            resetEditDraft(from: snapshot)
        }
    }

    func beginEditing() {
        prepareEditDraft()
        errorMessage = nil
        isEditing = true
    }

    func ensureEditingForCardMutation() {
        if !isEditing {
            prepareEditDraft()
            errorMessage = nil
            isEditing = true
        }
    }

    func requestCancelEditing() {
        if draftHasChanges {
            isConfirmingDiscardEdits = true
        } else {
            discardEditDraft()
        }
    }

    func discardEditDraft() {
        if let snapshot {
            resetEditDraft(from: snapshot)
        }
        errorMessage = nil
        isEditing = false
    }

    func resetEditDraft(from snapshot: MemoryDetailSnapshot) {
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

    var draftHasChanges: Bool {
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
    func saveEdits() async {
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

    var draftEditableArtifacts: [Artifact] {
        guard let snapshot else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        return draftArtifactOrder
            .filter { !draftDeletedArtifactIDs.contains($0) }
            .compactMap { artifactByID[$0] }
            .filter(\.isVisibleMemoryDetailAttachment)
    }

    var draftAddedAttachmentItems: [CaptureComposerAttachmentItem] {
        MemoryCardArrangementDraftEditing.attachmentItems(
            drafts: draftAddedArtifactDrafts,
            arrangement: draftAddedCardArrangement
        )
    }

    var mutationArtifactOrder: [UUID]? {
        guard let snapshot else { return nil }
        let originalRemainingOrder = orderedArtifacts(from: snapshot)
            .map(\.id)
            .filter { !draftDeletedArtifactIDs.contains($0) }
        let remainingDraftOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        return remainingDraftOrder == originalRemainingOrder ? nil : remainingDraftOrder
    }

    func updatedTextArtifactsForEditedBody() -> [Artifact] {
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

    func addedArtifactsForEditedDraft() -> [CaptureArtifactDraft] {
        draftAddedArtifactDrafts
    }

    func addedCardArrangementForEditedDraft() -> MemoryCardArrangementDraft? {
        draftAddedArtifactDrafts.isEmpty ? nil : draftAddedCardArrangement
    }

    func orderedArtifacts(from snapshot: MemoryDetailSnapshot) -> [Artifact] {
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        let ordered = snapshot.record.artifactIDs.compactMap { artifactByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let remaining = snapshot.artifacts
            .filter { !orderedIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        return ordered + remaining
    }

    func editBaseArrangement(for snapshot: MemoryDetailSnapshot) -> MemoryCardArrangement {
        snapshot.cardArrangement
            ?? MemoryCardArrangement.defaultArrangement(
                record: snapshot.record,
                artifacts: snapshot.artifacts,
                createdAt: snapshot.record.createdAt
            )
    }

    func stackDraftArtifactWithPrevious(_ artifactID: UUID) {
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

    func unstackDraftArtifact(_ artifactID: UUID) {
        guard let snapshot else { return }
        guard let arrangement = draftCardArrangement else { return }
        applyDraftCardArrangement(arrangement.unstackingContainingArtifactID(
            artifactID,
            artifacts: snapshot.artifacts,
            updatedAt: Date.now
        ))
    }

    func setDraftCardDensity(nodeID: UUID, density: MemoryCardContentDensity) {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.18)) {
            applyDraftCardArrangement(arrangement.settingContentDensity(density, forNodeID: nodeID, updatedAt: Date.now))
        }
    }

    func autoArrangeDraftCards() {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.22)) {
            applyDraftCardArrangement(arrangement.autoArranged(updatedAt: Date.now))
        }
    }

    func syncDraftCardArrangement() {
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

    func applyDraftCardArrangement(_ arrangement: MemoryCardArrangement) {
        draftCardArrangement = arrangement
        syncDraftArtifactOrder(with: arrangement)
    }

    func syncDraftArtifactOrder(with arrangement: MemoryCardArrangement) {
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

    var visibleDraftAttachmentIDs: [UUID] {
        guard let snapshot else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        return draftArtifactOrder
            .filter { !draftDeletedArtifactIDs.contains($0) }
            .filter { artifactByID[$0]?.isVisibleMemoryDetailAttachment == true }
    }
}

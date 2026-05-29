import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false
    @State private var isReloading = false
    @State private var isEditing = false
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

    private let productPathPolicy = MemoryDetailProductPathPolicy()

    var body: some View {
        Group {
            if let snapshot {
                if isEditing {
                    MemoryDetailEditingView(
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
                        onMoveArtifact: moveDraftArtifact(_:by:),
                        onMoveArtifactToAdjacentRow: moveDraftArtifactToAdjacentRow(_:direction:),
                        onSetArtifactSize: setDraftArtifactSize(_:size:),
                        onStackArtifactWithPrevious: stackDraftArtifactWithPrevious(_:),
                        onUnstackArtifact: unstackDraftArtifact(_:),
                        onAutoArrange: autoArrangeDraftCards
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            MemoryDeskRenderer(snapshot: snapshot)
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

    private func setDraftArtifactSize(_ artifactID: UUID, size: MemoryCardSizeToken) {
        guard let arrangement = draftCardArrangement else { return }
        applyDraftCardArrangement(arrangement.settingSize(size, forArtifactID: artifactID, updatedAt: Date.now))
    }

    private func stackDraftArtifactWithPrevious(_ artifactID: UUID) {
        guard let arrangement = draftCardArrangement else { return }
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

    private func moveDraftArtifactToAdjacentRow(_ artifactID: UUID, direction: MemoryCardBoardRowMoveDirection) {
        guard let arrangement = draftCardArrangement else { return }
        withAnimation(.snappy(duration: 0.2)) {
            applyDraftCardArrangement(
                arrangement.movingArtifactToAdjacentBoardRow(
                    artifactID: artifactID,
                    direction: direction,
                    updatedAt: Date.now
                )
            )
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
        updatedRecord.artifactIDs = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        let artifacts = snapshot.artifacts.filter { !draftDeletedArtifactIDs.contains($0.id) }
        applyDraftCardArrangement(arrangement.synchronized(
            record: updatedRecord,
            artifacts: artifacts,
            artifactOrder: updatedRecord.artifactIDs,
            updatedAt: Date.now
        ))
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
    @Binding var rawText: String
    @Binding var newArtifactKind: MemoryDetailNewArtifactKind
    @Binding var newArtifactTitle: String
    @Binding var newArtifactURL: String
    @Binding var newArtifactText: String

    let artifacts: [Artifact]
    let cardArrangement: MemoryCardArrangement?
    let errorMessage: String?
    var onDeleteArtifacts: ([UUID]) -> Void
    var onMoveArtifact: (UUID, Int) -> Void
    var onMoveArtifactToAdjacentRow: (UUID, MemoryCardBoardRowMoveDirection) -> Void
    var onSetArtifactSize: (UUID, MemoryCardSizeToken) -> Void
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
                        onMoveArtifact: onMoveArtifact,
                        onMoveArtifactToAdjacentRow: onMoveArtifactToAdjacentRow,
                        onSetArtifactSize: onSetArtifactSize,
                        onStackArtifactWithPrevious: onStackArtifactWithPrevious,
                        onUnstackArtifact: onUnstackArtifact,
                        onAutoArrange: onAutoArrange
                    )

                    supportingArtifactEditor
                        .padding(.horizontal, 20)
                        .padding(.top, artifacts.isEmpty ? 16 : 4)

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
    var onMoveArtifact: (UUID, Int) -> Void
    var onMoveArtifactToAdjacentRow: (UUID, MemoryCardBoardRowMoveDirection) -> Void
    var onSetArtifactSize: (UUID, MemoryCardSizeToken) -> Void
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
        MemoryDeskBoardLayoutPlan.make(
            nodes: boardNodes.map { MemoryDeskBoardInputNode(id: $0.id, layout: $0.layout) },
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
                            canMoveEarlier: canMove(slot.node, by: -1),
                            canMoveLater: canMove(slot.node, by: 1),
                            canMoveRowUp: canMoveRow(slot.node, direction: .up),
                            canMoveRowDown: canMoveRow(slot.node, direction: .down),
                            onDelete: { onDeleteArtifacts(slot.node.artifactIDs) },
                            onMoveEarlier: { onMoveArtifact(slot.node.primaryArtifactID, -1) },
                            onMoveLater: { onMoveArtifact(slot.node.primaryArtifactID, 1) },
                            onMoveRowUp: { onMoveArtifactToAdjacentRow(slot.node.primaryArtifactID, .up) },
                            onMoveRowDown: { onMoveArtifactToAdjacentRow(slot.node.primaryArtifactID, .down) },
                            onSetSize: { size in onSetArtifactSize(slot.node.primaryArtifactID, size) },
                            onStackWithPrevious: { onStackArtifactWithPrevious(slot.node.primaryArtifactID) },
                            onUnstack: { onUnstackArtifact(slot.node.primaryArtifactID) }
                        )
                        .frame(width: slot.frame.width, height: slot.frame.height, alignment: .center)
                        .position(
                            x: slot.frame.midX + slot.node.layout.xNudge,
                            y: slot.frame.midY + slot.node.layout.yNudge
                        )
                        .rotationEffect(.degrees(slot.node.layout.rotationDegrees))
                        .zIndex(Double(slot.node.layout.zIndex))
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

    private func canMoveRow(_ node: MemoryDetailEditingBoardNode, direction: MemoryCardBoardRowMoveDirection) -> Bool {
        guard let row = node.layout.gridPlacement?.row else { return false }
        let rows = Set(boardNodes.compactMap { $0.layout.gridPlacement?.row })
        switch direction {
        case .up:
            return rows.contains { $0 < row }
        case .down:
            return rows.contains { $0 > row }
        }
    }
}

private struct MemoryDetailEditingBoardCard: View {
    let node: MemoryDetailEditingBoardNode
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    let canMoveRowUp: Bool
    let canMoveRowDown: Bool
    var onDelete: () -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void
    var onMoveRowUp: () -> Void
    var onMoveRowDown: () -> Void
    var onSetSize: (MemoryCardSizeToken) -> Void
    var onStackWithPrevious: () -> Void
    var onUnstack: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CaptureCardView(
                presentation: CaptureCardPresentation(
                    item: node.item,
                    role: .detailEditing,
                    provenanceDisplayMode: .production,
                    surfaceMode: .skeuomorphic,
                    visualRecipe: node.visualRecipe,
                    visualVariant: node.visualVariant,
                    sizeToken: node.layout.size
                )
            )

            Menu {
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

                Button {
                    onMoveRowUp()
                } label: {
                    Label("Move Up Row", systemImage: "arrow.up.to.line.compact")
                }
                .disabled(!canMoveRowUp)

                Button {
                    onMoveRowDown()
                } label: {
                    Label("Move Down Row", systemImage: "arrow.down.to.line.compact")
                }
                .disabled(!canMoveRowDown)

                Divider()

                Menu("memory.arrangement.size") {
                    ForEach(supportedSizes) { size in
                        Button(size.rawValue) {
                            onSetSize(size)
                        }
                    }
                }

                Button {
                    onStackWithPrevious()
                } label: {
                    Label("memory.arrangement.stackWithPrevious", systemImage: "square.stack.3d.up")
                }

                Button {
                    onUnstack()
                } label: {
                    Label("memory.arrangement.unstack", systemImage: "square.split.2x1")
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

    private var supportedSizes: [MemoryCardSizeToken] {
        MemoryCardRecipeLayoutPolicy.supportedSizes(for: node.visualRecipe)
    }
}

private struct MemoryDetailEditingBoardNode: Identifiable {
    let id: UUID
    let artifactIDs: [UUID]
    let item: CaptureCardItem
    let visualRecipe: MemoryCardVisualRecipe
    let visualVariant: MemoryCardVisualVariant?
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
        self.item = artifacts.count == 1
            ? CaptureCardItem(artifact: artifacts[0])
            : Self.groupItem(nodeID: node.id, artifacts: artifacts)
        self.visualRecipe = node.visualRecipe
        self.visualVariant = node.visualVariant
        self.layout = node.layout
    }

    private static func groupItem(nodeID: UUID, artifacts: [Artifact]) -> CaptureCardItem {
        let thumbnail = artifacts.compactMap { $0.previewPayload ?? $0.binaryPayload }.first
        return CaptureCardItem(
            id: "edit-group-\(nodeID.uuidString)",
            payload: .photo(CapturePhotoCardPayload(thumbnailData: thumbnail, photoCount: artifacts.count, groupStyle: .stack)),
            origin: artifacts.first?.captureProvenance?.artifactOrigin,
            provenance: artifacts.first?.captureProvenance,
            title: "Stack",
            detail: artifacts.map(\.title).compactMap(\.trimmedOrNil).prefix(3).joined(separator: " · "),
            metadata: "\(artifacts.count)"
        )
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

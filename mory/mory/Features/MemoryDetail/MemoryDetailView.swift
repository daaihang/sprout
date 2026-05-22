import SwiftUI

struct MemoryDetailView: View {
    @Environment(\.memoryRepository) private var memoryRepository

    let recordID: UUID

    @State private var snapshot: MemoryDetailSnapshot?
    @State private var userPreference = UserSettingsPreference.defaults
    @State private var recordPreference: MemoryDetailPresentationPreference?
    @State private var errorMessage: String?
    @State private var isRefreshingPipeline = false
    @State private var isReloading = false
    @State private var isEditing = false
    @State private var draftRawText = ""
    @State private var draftArtifactOrder: [UUID] = []
    @State private var draftDeletedArtifactIDs: Set<UUID> = []
    @State private var isSavingEdits = false
    @State private var isConfirmingDiscardEdits = false

    private let resolver = MemoryDetailPresentationResolver()

    private var presentation: MemoryDetailPresentationSnapshot? {
        guard let snapshot else { return nil }
        return resolver.resolve(
            snapshot: snapshot,
            userPreference: userPreference,
            recordPreference: recordPreference
        )
    }

    var body: some View {
        Group {
            if snapshot != nil, let presentation {
                if isEditing {
                    MemoryDetailEditingView(
                        rawText: $draftRawText,
                        artifacts: draftEditableArtifacts,
                        errorMessage: errorMessage,
                        onDeleteArtifact: { artifactID in
                            withAnimation(.snappy(duration: 0.2)) {
                                _ = draftDeletedArtifactIDs.insert(artifactID)
                            }
                        },
                        onMoveArtifact: moveDraftArtifact(_:by:),
                        onReorderArtifact: reorderDraftArtifact(_:near:)
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            MemoryDetailAdaptiveView(presentation: presentation)
                            MemoryDetailInsightPanel(presentation: presentation)
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

                    Button(isRefreshingPipeline ? String(localized: "memory.analysis.retrying") : String(localized: "memory.analysis.retry")) {
                        Task { await refreshPipeline() }
                    }
                    .disabled(isRefreshingPipeline)

                    Divider()

                    Button {
                        clearPresentationMode()
                    } label: {
                        Label("Automatic layout", systemImage: recordPreference == nil ? "checkmark" : "wand.and.stars")
                    }

                    ForEach(MemoryDetailPresentationMode.allCases) { mode in
                        Button {
                            savePresentationMode(mode)
                        } label: {
                            Label(mode.title, systemImage: recordPreference?.mode == mode ? "checkmark" : mode.systemImage)
                        }
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
            userPreference = try memoryRepository.fetchUserSettingsPreference()
            recordPreference = try memoryRepository.fetchMemoryDetailPresentationPreference(recordID: recordID)
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
        draftDeletedArtifactIDs = []
    }

    private var draftHasChanges: Bool {
        guard let snapshot else {
            return false
        }
        let record = snapshot.record
        if draftRawText != record.rawText { return true }
        if !draftDeletedArtifactIDs.isEmpty { return true }
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
                    updatedArtifacts: updatedTextArtifactsForEditedBody(),
                    deletedArtifactIDs: Array(draftDeletedArtifactIDs),
                    artifactOrder: mutationArtifactOrder
                ),
                refreshPolicy: .runImmediately
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

    private func orderedArtifacts(from snapshot: MemoryDetailSnapshot) -> [Artifact] {
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        let ordered = snapshot.record.artifactIDs.compactMap { artifactByID[$0] }
        let orderedIDs = Set(ordered.map(\.id))
        let remaining = snapshot.artifacts
            .filter { !orderedIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        return ordered + remaining
    }

    private func canMoveDraftArtifact(_ id: UUID, by offset: Int) -> Bool {
        let visibleOrder = visibleDraftAttachmentIDs
        guard let visibleIndex = visibleOrder.firstIndex(of: id) else { return false }
        let targetIndex = visibleIndex + offset
        return visibleOrder.indices.contains(targetIndex)
    }

    private func moveDraftArtifact(_ id: UUID, by offset: Int) {
        let visibleOrder = visibleDraftAttachmentIDs
        guard let visibleIndex = visibleOrder.firstIndex(of: id) else { return }
        let targetVisibleIndex = visibleIndex + offset
        guard visibleOrder.indices.contains(targetVisibleIndex) else { return }

        let targetID = visibleOrder[targetVisibleIndex]
        guard let sourceIndex = draftArtifactOrder.firstIndex(of: id),
              let targetIndex = draftArtifactOrder.firstIndex(of: targetID) else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            draftArtifactOrder.swapAt(sourceIndex, targetIndex)
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
        }
    }

    private var visibleDraftAttachmentIDs: [UUID] {
        guard let snapshot else { return [] }
        let artifactByID = Dictionary(uniqueKeysWithValues: snapshot.artifacts.map { ($0.id, $0) })
        return draftArtifactOrder
            .filter { !draftDeletedArtifactIDs.contains($0) }
            .filter { artifactByID[$0]?.isVisibleMemoryDetailAttachment == true }
    }

    private func savePresentationMode(_ mode: MemoryDetailPresentationMode) {
        do {
            let preference = MemoryDetailPresentationPreference(recordID: recordID, mode: mode)
            try memoryRepository.saveMemoryDetailPresentationPreference(preference)
            recordPreference = preference
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearPresentationMode() {
        do {
            try memoryRepository.clearMemoryDetailPresentationPreference(recordID: recordID)
            recordPreference = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemoryDetailEditingView: View {
    @Binding var rawText: String

    let artifacts: [Artifact]
    let errorMessage: String?
    var onDeleteArtifact: (UUID) -> Void
    var onMoveArtifact: (UUID, Int) -> Void
    var onReorderArtifact: (UUID, UUID) -> Void

    @FocusState private var isBodyFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    artifactCarousel

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

    @ViewBuilder
    private var artifactCarousel: some View {
        if !artifacts.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(artifacts.enumerated()), id: \.element.id) { index, artifact in
                        MemoryDetailEditingArtifactCard(
                            artifact: artifact,
                            canMoveEarlier: index > 0,
                            canMoveLater: index < artifacts.count - 1,
                            onDelete: { onDeleteArtifact(artifact.id) },
                            onMoveEarlier: { onMoveArtifact(artifact.id, -1) },
                            onMoveLater: { onMoveArtifact(artifact.id, 1) }
                        )
                        .draggable(artifact.id.uuidString)
                        .dropDestination(for: String.self) { droppedIDs, _ in
                            guard let rawID = droppedIDs.first,
                                  let sourceID = UUID(uuidString: rawID) else {
                                return false
                            }
                            onReorderArtifact(sourceID, artifact.id)
                            return true
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .frame(height: 148)
            .padding(.top, 4)
        }
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

private struct MemoryDetailEditingArtifactCard: View {
    let artifact: Artifact
    let canMoveEarlier: Bool
    let canMoveLater: Bool
    var onDelete: () -> Void
    var onMoveEarlier: () -> Void
    var onMoveLater: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CaptureCardView(presentation: .detailEditing(artifact))

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

private extension Artifact {
    var isVisibleMemoryDetailAttachment: Bool {
        kind != .text
    }
}

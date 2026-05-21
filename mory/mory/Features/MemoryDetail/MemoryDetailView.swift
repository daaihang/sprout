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
    @State private var draftMood = ""
    @State private var draftInputContext = ""
    @State private var draftArtifactText = ""
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
                        mood: $draftMood,
                        inputContext: $draftInputContext,
                        addedText: $draftArtifactText,
                        artifacts: draftEditableArtifacts,
                        deletedArtifactCount: draftDeletedArtifactIDs.count,
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
        draftMood = record.userMood ?? ""
        draftInputContext = record.inputContext ?? ""
        draftArtifactText = ""
        draftArtifactOrder = orderedArtifacts(from: snapshot).map(\.id)
        draftDeletedArtifactIDs = []
    }

    private var draftHasChanges: Bool {
        guard let snapshot else {
            return false
        }
        let record = snapshot.record
        if draftRawText != record.rawText { return true }
        if draftMood.trimmedOrNil != record.userMood?.trimmedOrNil { return true }
        if draftInputContext.trimmedOrNil != record.inputContext?.trimmedOrNil { return true }
        if draftArtifactText.trimmedOrNil != nil { return true }
        if !draftDeletedArtifactIDs.isEmpty { return true }
        return mutationArtifactOrder != nil
    }

    @MainActor
    private func saveEdits() async {
        guard !isSavingEdits else { return }
        isSavingEdits = true
        defer { isSavingEdits = false }

        do {
            let addedArtifacts: [CaptureArtifactDraft]
            if let appendedArtifactText = draftArtifactText.trimmedOrNil {
                addedArtifacts = [.text(title: appendedArtifactText.firstMeaningfulLine ?? "Added Note", body: appendedArtifactText)]
            } else {
                addedArtifacts = []
            }

            let result = try await memoryRepository.applyMemoryMutation(
                recordID: recordID,
                mutation: MemoryMutationDraft(
                    recordPatch: MemoryMutationRecordPatch(
                        rawText: .set(draftRawText),
                        userMood: .set(draftMood.trimmedOrNil),
                        inputContext: .set(draftInputContext.trimmedOrNil)
                    ),
                    addedArtifacts: addedArtifacts,
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
    }

    private var mutationArtifactOrder: [UUID]? {
        guard let snapshot else { return nil }
        let originalRemainingOrder = orderedArtifacts(from: snapshot)
            .map(\.id)
            .filter { !draftDeletedArtifactIDs.contains($0) }
        let remainingDraftOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        return remainingDraftOrder == originalRemainingOrder ? nil : remainingDraftOrder
    }

    private func editableArtifactRow(_ artifact: Artifact) -> some View {
        HStack(spacing: 12) {
            Image(systemName: artifact.kind.memoryDetailEditSystemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(artifact.memoryDetailEditTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(artifact.memoryDetailEditSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Button {
                    moveDraftArtifact(artifact.id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(!canMoveDraftArtifact(artifact.id, by: -1))
                .accessibilityLabel("memory.edit.moveAttachmentUp")

                Button {
                    moveDraftArtifact(artifact.id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(!canMoveDraftArtifact(artifact.id, by: 1))
                .accessibilityLabel("memory.edit.moveAttachmentDown")

                Button(role: .destructive) {
                    draftDeletedArtifactIDs.insert(artifact.id)
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("common.delete")
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)
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
        let visibleOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
        guard let visibleIndex = visibleOrder.firstIndex(of: id) else { return false }
        let targetIndex = visibleIndex + offset
        return visibleOrder.indices.contains(targetIndex)
    }

    private func moveDraftArtifact(_ id: UUID, by offset: Int) {
        let visibleOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
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
        let visibleOrder = draftArtifactOrder.filter { !draftDeletedArtifactIDs.contains($0) }
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
    @Binding var mood: String
    @Binding var inputContext: String
    @Binding var addedText: String

    let artifacts: [Artifact]
    let deletedArtifactCount: Int
    let errorMessage: String?
    var onDeleteArtifact: (UUID) -> Void
    var onMoveArtifact: (UUID, Int) -> Void
    var onReorderArtifact: (UUID, UUID) -> Void

    @State private var showsDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                bodyEditor
                detailDisclosure
                addedTextEditor
                artifactSection
                statusSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(Color(.systemBackground))
    }

    private var bodyEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $rawText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 240)
                .padding(.horizontal, -5)

            if rawText.isEmpty {
                Text("memory.edit.body.placeholder")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityLabel("memory.label.rawCapture")
    }

    private var detailDisclosure: some View {
        DisclosureGroup(isExpanded: $showsDetails) {
            VStack(alignment: .leading, spacing: 14) {
                TextField("memory.label.mood", text: $mood)
                    .textFieldStyle(.roundedBorder)
                TextField("memory.label.context", text: $inputContext, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, 10)
        } label: {
            Text("memory.edit.details")
                .font(.headline)
        }
    }

    private var addedTextEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("memory.edit.addAttachment")
                .font(.headline)
            TextField("memory.edit.addAttachment.placeholder", text: $addedText, axis: .vertical)
                .lineLimit(2...6)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var artifactSection: some View {
        if !artifacts.isEmpty || deletedArtifactCount > 0 {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("memory.edit.existingAttachments")
                        .font(.headline)
                    Text("memory.edit.attachments.footer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 190, maximum: 220), spacing: 12, alignment: .top)],
                    alignment: .leading,
                    spacing: 12
                ) {
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

                if deletedArtifactCount > 0 {
                    Text(String(format: String(localized: "memory.edit.deletedAttachments.format"), Int64(deletedArtifactCount)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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
    var memoryDetailEditTitle: String {
        title.trimmedOrNil
            ?? metadata["trackName"]?.trimmedOrNil
            ?? metadata["condition"]?.trimmedOrNil
            ?? kind.memoryDetailEditLabel
    }

    var memoryDetailEditSubtitle: String {
        switch kind {
        case .music:
            return [metadata["artistName"], metadata["albumName"]]
                .compactMap { $0?.trimmedOrNil }
                .joined(separator: " · ")
                .trimmedOrNil
                ?? summaryOrFallback
        case .weather:
            if let condition = metadata["condition"]?.trimmedOrNil,
               let temperature = metadata["temperatureCelsius"]?.trimmedOrNil {
                return "\(condition) · \(temperature)°C"
            }
            return summaryOrFallback
        case .location:
            return summary.trimmedOrNil ?? title.trimmedOrNil ?? kind.memoryDetailEditLabel
        case .audio:
            return metadata["transcriptionText"]?.trimmedOrNil
                ?? summary.trimmedOrNil
                ?? mediaRef?.filename
                ?? kind.memoryDetailEditLabel
        case .link:
            return metadata["url"]?.trimmedOrNil
                ?? summary.trimmedOrNil
                ?? kind.memoryDetailEditLabel
        default:
            return summaryOrFallback
        }
    }

    private var summaryOrFallback: String {
        summary.trimmedOrNil
            ?? textContent.trimmedOrNil
            ?? mediaRef?.filename
            ?? kind.memoryDetailEditLabel
    }
}

private extension ArtifactKind {
    var memoryDetailEditLabel: String {
        switch self {
        case .text: return String(localized: "capture.card.kind.text")
        case .photo: return String(localized: "capture.card.kind.photo")
        case .audio: return String(localized: "capture.card.kind.audio")
        case .music: return String(localized: "capture.card.kind.music")
        case .link: return String(localized: "capture.card.kind.link")
        case .location: return String(localized: "capture.card.kind.place")
        case .weather: return String(localized: "capture.card.kind.weather")
        case .todo: return String(localized: "capture.card.kind.todo")
        case .document: return String(localized: "capture.card.kind.status")
        }
    }

    var memoryDetailEditSystemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .photo: return "photo"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .link: return "link"
        case .location: return "mappin.and.ellipse"
        case .weather: return "cloud.sun"
        case .todo: return "checklist"
        case .document: return "doc.text"
        }
    }
}

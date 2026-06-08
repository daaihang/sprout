import PhotosUI
import SwiftUI
import UIKit

extension MemoryDetailView {
    func detailAddMenu(labelStyle: MemoryAddCardMenu.LabelStyle) -> some View {
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
    func detailSheetContent(for sheet: CaptureComposerSheet) -> some View {
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
    func appendDraftAddedArtifact(_ draft: CaptureArtifactDraft) {
        ensureEditingForCardMutation()
        draftAddedArtifactDrafts.append(draft)
        draftAddedCardArrangement.appendArtifactDraft(draft)
    }

    @MainActor
    func addPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        ensureEditingForCardMutation()
        isProcessingPhoto = true
        defer {
            isProcessingPhoto = false
            selectedPhotoItems = []
        }

        let result = await MemoryCardDraftMediaAdder.drafts(fromPhotoItems: items)
        result.drafts.forEach(appendDraftAddedArtifact)
        if let message = result.firstErrorMessage {
            errorMessage = message
        }
    }

    @MainActor
    func addCameraImage(_ image: UIImage) async {
        ensureEditingForCardMutation()
        isProcessingPhoto = true
        defer { isProcessingPhoto = false }
        if let draft = await MemoryCardDraftMediaAdder.draft(fromCameraImage: image) {
            appendDraftAddedArtifact(draft)
        }
    }

    @MainActor
    func addPhotoData(_ data: Data, filename: String) async {
        appendDraftAddedArtifact(
            await MemoryCardDraftMediaAdder.draft(
                fromPhotoData: data,
                filename: filename,
                provenance: MemoryCardDraftMediaAdder.manualProvenance(.camera)
            )
        )
    }

    @MainActor
    func removeAddedDraft(at index: Int) {
        MemoryCardArrangementDraftEditing.removeDraft(
            at: index,
            drafts: &draftAddedArtifactDrafts,
            arrangement: &draftAddedCardArrangement
        )
    }

    @MainActor
    func removeAddedDraftGroup(_ draftIDs: [UUID]) {
        MemoryCardArrangementDraftEditing.removeDraftGroup(
            draftIDs,
            drafts: &draftAddedArtifactDrafts,
            arrangement: &draftAddedCardArrangement
        )
    }

    @MainActor
    func setAddedDraftDensity(item: CaptureComposerAttachmentItem, density: MemoryCardContentDensity) {
        withAnimation(.snappy(duration: 0.18)) {
            MemoryCardArrangementDraftEditing.setDensity(
                density,
                for: item,
                drafts: draftAddedArtifactDrafts,
                arrangement: &draftAddedCardArrangement
            )
        }
    }

    @MainActor
    func reorderAddedDraftItem(from source: CaptureComposerAttachmentItem, to target: CaptureComposerAttachmentItem) {
        withAnimation(.snappy(duration: 0.2)) {
            MemoryCardArrangementDraftEditing.reorder(
                source: source,
                target: target,
                drafts: draftAddedArtifactDrafts,
                arrangement: &draftAddedCardArrangement
            )
        }
    }

    @MainActor
    func stackAddedDraftWithPrevious(item: CaptureComposerAttachmentItem) {
        withAnimation(.snappy(duration: 0.18)) {
            MemoryCardArrangementDraftEditing.stackWithPrevious(
                item: item,
                drafts: draftAddedArtifactDrafts,
                arrangement: &draftAddedCardArrangement
            )
        }
    }

    @MainActor
    func unstackAddedDraft(item: CaptureComposerAttachmentItem) {
        withAnimation(.snappy(duration: 0.18)) {
            MemoryCardArrangementDraftEditing.unstack(
                item: item,
                drafts: draftAddedArtifactDrafts,
                arrangement: &draftAddedCardArrangement
            )
        }
    }

    func manualProvenance(_ sourceKind: CaptureProvenanceSourceKind) -> CaptureProvenance {
        MemoryCardDraftMediaAdder.manualProvenance(sourceKind)
    }

}

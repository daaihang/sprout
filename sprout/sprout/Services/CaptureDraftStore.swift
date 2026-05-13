import Foundation
import Observation

@Observable
@MainActor
final class CaptureDraftStore {
    var draft: CaptureDraft

    private var restorableDraft: CaptureDraft?

    init() {
        self.draft = CaptureDraft()
    }

    init(draft: CaptureDraft) {
        self.draft = draft
    }

    var hasContent: Bool {
        draft.hasContent
    }

    var hasRestorableDraft: Bool {
        restorableDraft?.hasContent == true
    }

    var hasAnyDraft: Bool {
        draft.hasContent || hasRestorableDraft
    }

    func handleComposerPresentationChange(isPresented: Bool) {
        if isPresented {
            restoreIfNeeded()
        } else {
            stashForRestore()
        }
    }

    func stashForRestore() {
        guard draft.hasContent else {
            restorableDraft = nil
            return
        }
        restorableDraft = draft
    }

    func restoreIfNeeded() {
        guard !draft.hasContent, let restorableDraft, restorableDraft.hasContent else { return }
        draft = restorableDraft
    }

    func reset() {
        draft.clear()
        restorableDraft = nil
    }

    func discardDraft() {
        reset()
    }

    func currentSubmissionDraft() -> CaptureDraft? {
        let current = draft
        guard current.hasContent else { return nil }
        return current
    }
}

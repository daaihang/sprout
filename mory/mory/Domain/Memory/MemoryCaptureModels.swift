import Foundation

struct MemoryCaptureDraft: Hashable, Sendable {
    var title: String?
    var rawText: String
    var mood: String?
    var inputContext: String?
    var provenance: CaptureProvenance
    var artifacts: [CaptureArtifactDraft]
    var affectSnapshots: [AffectSnapshotDraft]

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        provenance: CaptureProvenance = .manualComposer,
        artifacts: [CaptureArtifactDraft] = [],
        affectSnapshots: [AffectSnapshotDraft] = []
    ) {
        self.title = title
        self.rawText = rawText
        self.mood = mood
        self.inputContext = inputContext
        self.provenance = provenance
        self.artifacts = artifacts
        self.affectSnapshots = affectSnapshots
    }

    init(
        title: String? = nil,
        rawText: String,
        mood: String? = nil,
        inputContext: String? = nil,
        captureSource: CaptureSource,
        provenance: CaptureProvenance? = nil,
        artifacts: [CaptureArtifactDraft] = [],
        affectSnapshots: [AffectSnapshotDraft] = []
    ) {
        self.init(
            title: title,
            rawText: rawText,
            mood: mood,
            inputContext: inputContext,
            provenance: provenance ?? captureSource.defaultProvenance,
            artifacts: artifacts,
            affectSnapshots: affectSnapshots
        )
    }

    func withExternalInboxItemID(_ id: UUID?) -> MemoryCaptureDraft {
        var copy = self
        copy.provenance = provenance.withExternalInboxItemID(id)
        copy.artifacts = artifacts.map { artifact in
            guard let provenance = artifact.provenance else { return artifact }
            return artifact.withProvenance(provenance.withExternalInboxItemID(id))
        }
        copy.affectSnapshots = affectSnapshots.map { draft in
            var draft = draft
            if let provenance = draft.provenance {
                draft.provenance = provenance.withExternalInboxItemID(id)
            }
            return draft
        }
        return copy
    }
}

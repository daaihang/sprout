import Foundation

extension MemoryCardContentRef {
    var artifactIDs: [UUID] {
        switch self {
        case let .artifact(id):
            return [id]
        case let .artifactGroup(ids, _):
            return ids
        case .recordBody, .affect, .journalingSuggestion:
            return []
        }
    }
}

extension MemoryCardDraftContentRef {
    var artifactDraftIDs: [UUID] {
        switch self {
        case let .artifactDraft(id):
            return [id]
        case let .artifactDraftGroup(ids, _):
            return ids
        case .recordBody, .affectDraft, .journalingSuggestion:
            return []
        }
    }
}

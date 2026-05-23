import Foundation

struct JournalingSuggestionContextService: Sendable {
    private let capabilityProvider: any JournalingSuggestionCapabilityProviding

    init(capabilityProvider: any JournalingSuggestionCapabilityProviding = DefaultJournalingSuggestionCapabilityProvider()) {
        self.capabilityProvider = capabilityProvider
    }

    func availability() -> JournalingSuggestionAvailability {
        guard capabilityProvider.supportsJournalingSuggestions else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .unsupportedOS,
                detail: "Journaling Suggestions requires iOS 17.2 or later."
            )
        }
        guard capabilityProvider.hasJournalingSuggestionEntitlement else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .missingEntitlement,
                detail: "Current app entitlements do not include com.apple.developer.journal.allow."
            )
        }
        guard capabilityProvider.userEnabledJournalingSuggestions else {
            return JournalingSuggestionAvailability(
                isAvailable: false,
                reason: .disabledByUser,
                detail: "User has disabled Journaling Suggestions for Mory."
            )
        }
        return .available
    }

    func makeCaptureDraft(from suggestion: JournalingSuggestionDraft) -> MemoryCaptureDraft {
        let request = ExternalCaptureRequest(
            sourceKind: .journalingSuggestion,
            receivedAt: suggestion.createdAt,
            title: suggestion.title,
            text: suggestion.body?.trimmedOrNil ?? suggestion.title?.trimmedOrNil ?? "Journaling suggestion",
            context: "journalingSuggestion:selectedAt=\(suggestion.createdAt.formatted(.iso8601))",
            evidenceItems: suggestion.evidenceItems,
            affectEvidence: suggestion.affectEvidence,
            attachments: suggestion.attachments,
            diagnostics: suggestion.diagnostics
        )
        var draft = ExternalCaptureDraftFactory().makeDraft(from: request)
        draft.captureSource = .composer
        return draft
    }
}

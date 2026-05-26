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
        ExternalCaptureDraftFactory().makeDraft(from: suggestion)
    }
}

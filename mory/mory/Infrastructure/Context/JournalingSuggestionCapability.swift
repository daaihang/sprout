import Foundation

enum JournalingSuggestionAvailabilityReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case available
    case unsupportedOS
    case missingEntitlement
    case disabledByUser
    case frameworkNotLinked

    var id: String { rawValue }
}

struct JournalingSuggestionAvailability: Codable, Hashable, Sendable {
    var isAvailable: Bool
    var reason: JournalingSuggestionAvailabilityReason
    var detail: String

    static var available: JournalingSuggestionAvailability {
        JournalingSuggestionAvailability(
            isAvailable: true,
            reason: .available,
            detail: "Journaling Suggestions capability is available."
        )
    }
}

protocol JournalingSuggestionCapabilityProviding: Sendable {
    var supportsJournalingSuggestions: Bool { get }
    var hasJournalingSuggestionEntitlement: Bool { get }
    var userEnabledJournalingSuggestions: Bool { get }
}

struct DefaultJournalingSuggestionCapabilityProvider: JournalingSuggestionCapabilityProviding {
    var supportsJournalingSuggestions: Bool {
        #if os(iOS) && canImport(JournalingSuggestions)
        if #available(iOS 17.2, *) {
            true
        } else {
            false
        }
        #else
        false
        #endif
    }

    var hasJournalingSuggestionEntitlement: Bool {
        true
    }

    var userEnabledJournalingSuggestions: Bool {
        true
    }
}

import Foundation

enum SpotlightSearchableItemIdentifier {
    static let memoryDomain = "mory.memory"

    static func memory(_ id: UUID) -> String {
        "\(memoryDomain).\(id.uuidString)"
    }

    static func parseMemoryID(from uniqueIdentifier: String) -> UUID? {
        let prefix = "\(memoryDomain)."
        guard uniqueIdentifier.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(uniqueIdentifier.dropFirst(prefix.count)))
    }
}

struct SpotlightSearchHit: Hashable, Sendable {
    let uniqueIdentifier: String
    let memoryID: UUID
}

import Foundation

enum SpotlightSearchableItemIdentifier {
    static let memoryDomain = "mory.memory"

    static func memoryDomain(ownerID: String?) -> String {
        guard let ownerID = ownerID?.trimmedOrNil else {
            return memoryDomain
        }
        return "\(memoryDomain).\(ownerStorageDirectoryName(ownerID))"
    }

    static func memory(_ id: UUID, ownerID: String? = nil) -> String {
        "\(memoryDomain(ownerID: ownerID)).\(id.uuidString)"
    }

    static func parseMemoryID(from uniqueIdentifier: String) -> UUID? {
        guard uniqueIdentifier.hasPrefix("\(memoryDomain).") else { return nil }
        guard let idComponent = uniqueIdentifier.split(separator: ".").last else { return nil }
        return UUID(uuidString: String(idComponent))
    }

    private static func ownerStorageDirectoryName(_ ownerID: String) -> String {
        let sanitized = ownerID.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
        }.joined()
        let limited = String(sanitized.prefix(48)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let prefix = limited.isEmpty ? "owner" : limited
        return "\(prefix)-\(stableHashHex(ownerID))"
    }

    private static func stableHashHex(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct SpotlightSearchHit: Hashable, Sendable {
    let uniqueIdentifier: String
    let memoryID: UUID
}

import Foundation

enum SelfReferenceResolutionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case selfMention
    case ownedRoleMention
    case ambiguousRoleMention
    case notSelfMention

    var id: String { rawValue }
}

struct SelfReferenceResolution: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: SelfReferenceResolutionKind
    var text: String
    var targetEntityID: UUID?
    var confidence: Double
    var reason: String

    init(
        id: UUID = UUID(),
        kind: SelfReferenceResolutionKind,
        text: String,
        targetEntityID: UUID? = nil,
        confidence: Double,
        reason: String
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.targetEntityID = targetEntityID
        self.confidence = confidence
        self.reason = reason
    }
}

struct SelfReferenceResolver {
    private let ownedRolePatterns = [
        "my roommate",
        "my housemate",
        "my boss",
        "my manager",
        "my mom",
        "my mother",
        "my dad",
        "my father",
        "my partner",
        "我的室友",
        "我室友",
        "我的老板",
        "我老板",
        "我妈",
        "我妈妈",
        "我爸",
        "我爸爸",
        "我的对象"
    ]

    private let ambiguousRolePatterns = [
        "roommate",
        "housemate",
        "boss",
        "manager",
        "室友",
        "老板",
        "同事",
        "舍友"
    ]

    func resolve(text: String, selfProfile: SelfProfile) -> [SelfReferenceResolution] {
        let normalizedText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        var resolutions: [SelfReferenceResolution] = []

        if normalizedText.contains("not me") || normalizedText.contains("不是我") {
            resolutions.append(
                SelfReferenceResolution(
                    kind: .notSelfMention,
                    text: "not me",
                    confidence: 0.9,
                    reason: "Explicit negative self-reference phrase."
                )
            )
        }

        if let alias = selfProfile.aliases.first(where: { containsToken($0, in: normalizedText) }) {
            resolutions.append(
                SelfReferenceResolution(
                    kind: .selfMention,
                    text: alias,
                    targetEntityID: selfProfile.selfEntityID,
                    confidence: 0.95,
                    reason: "Matched SelfProfile alias."
                )
            )
        }

        for pattern in ownedRolePatterns where normalizedText.contains(pattern) {
            resolutions.append(
                SelfReferenceResolution(
                    kind: .ownedRoleMention,
                    text: pattern,
                    targetEntityID: selfProfile.selfEntityID,
                    confidence: 0.8,
                    reason: "Role mention is explicitly owned by the user."
                )
            )
        }

        if !resolutions.contains(where: { $0.kind == .ownedRoleMention }) {
            for pattern in ambiguousRolePatterns where normalizedText.contains(pattern) {
                resolutions.append(
                    SelfReferenceResolution(
                        kind: .ambiguousRoleMention,
                        text: pattern,
                        confidence: 0.55,
                        reason: "Role label is present but not tied to a concrete person."
                    )
                )
            }
        }

        if resolutions.isEmpty {
            resolutions.append(
                SelfReferenceResolution(
                    kind: .notSelfMention,
                    text: "",
                    confidence: 0.4,
                    reason: "No self-reference rule matched."
                )
            )
        }

        return resolutions
    }

    private func containsToken(_ token: String, in normalizedText: String) -> Bool {
        let normalizedToken = token.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !normalizedToken.isEmpty else { return false }
        if containsCJK(normalizedToken) {
            return containsCJKToken(normalizedToken, in: normalizedText)
        }
        if normalizedToken.rangeOfCharacter(from: .letters.inverted) == nil,
           normalizedToken.unicodeScalars.allSatisfy(\.isASCII) {
            return normalizedText
                .split(whereSeparator: { !$0.isLetter })
                .contains { $0 == normalizedToken }
        }
        return normalizedText.contains(normalizedToken)
    }

    private func containsCJKToken(_ token: String, in text: String) -> Bool {
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: token, range: searchRange) {
            if token == "我",
               range.upperBound < text.endIndex,
               text[range.upperBound] == "们" {
                searchRange = range.upperBound..<text.endIndex
                continue
            }
            return true
        }
        return false
    }

    private func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains(where: isCJK)
    }

    private func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF:
            return true
        default:
            return false
        }
    }
}

import Foundation

extension String {
    var trimmedOrNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var firstMeaningfulLine: String? {
        split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    func generatedMemoryTitle(maxLength: Int = 48) -> String? {
        guard let line = firstMeaningfulLine else { return nil }
        let sentenceTerminators = CharacterSet(charactersIn: ".!?。！？;；")
        let sentence = line.unicodeScalars.firstIndex(where: { sentenceTerminators.contains($0) })
            .map { String(line.unicodeScalars[..<$0]) }
            ?? line
        let normalized = sentence
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !normalized.isEmpty else { return nil }
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }

    func ifEmpty(_ fallback: String) -> String {
        trimmedOrNil ?? fallback
    }
}

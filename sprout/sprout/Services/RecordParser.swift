import Foundation

// MARK: - ParsedContent

struct ParsedContent {
    var appleMusicURLs: [URL] = []
    var regularURLs: [URL] = []

    var hasAppleMusic: Bool { !appleMusicURLs.isEmpty }
    var hasLinks: Bool { !regularURLs.isEmpty }
    var hasAnyURL: Bool { hasAppleMusic || hasLinks }
}

// MARK: - RecordParser

enum RecordParser {

    /// Scans a text body and returns detected special content.
    /// Currently detects Apple Music URLs and generic web links.
    static func parseBody(_ text: String) -> ParsedContent {
        var result = ParsedContent()

        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return result }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, options: [], range: range)

        for match in matches {
            guard let url = match.url else { continue }
            let host = url.host ?? ""
            if host.contains("music.apple.com") || host.contains("itunes.apple.com") {
                result.appleMusicURLs.append(url)
            } else {
                result.regularURLs.append(url)
            }
        }

        return result
    }

    /// Determines the best `cardType` string for a record given its parsed content.
    static func primaryCardType(body: String, parsed: ParsedContent) -> String {
        if parsed.hasAppleMusic { return "music" }
        if parsed.hasLinks      { return "link"  }
        if !body.isEmpty        { return "text"  }
        return "text"
    }
}

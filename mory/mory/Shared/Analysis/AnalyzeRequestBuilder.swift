import Foundation

struct AnalyzeRequestBuilder {
    func build(record: RecordShell, artifacts: [Artifact]) -> AnalyzeRequestPayload {
        let artifactSummary = artifacts
            .map { "\($0.kind.rawValue): \($0.title) \($0.summary)".trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        let content = [record.rawText, artifactSummary]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")

        return AnalyzeRequestPayload(
            record: .init(
                id: record.id.uuidString,
                content: content,
                createdAt: ISO8601DateFormatter().string(from: record.createdAt),
                tags: []
            ),
            persons: []
        )
    }
}

struct AnalyzeRequestPayload: Codable, Sendable {
    struct Record: Codable, Sendable {
        var id: String
        var content: String
        var createdAt: String
        var tags: [String]

        enum CodingKeys: String, CodingKey {
            case id
            case content
            case createdAt = "created_at"
            case tags
        }
    }

    struct Person: Codable, Sendable {
        var id: String?
        var name: String
        var relationship: String?
        var lastMentionedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case relationship
            case lastMentionedAt = "last_mentioned_at"
        }
    }

    var record: Record
    var persons: [Person]
}

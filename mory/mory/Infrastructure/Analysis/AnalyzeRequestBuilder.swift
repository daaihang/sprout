import Foundation

struct AnalyzeRequestBuilder {
    private let dateFormatter = ISO8601DateFormatter()

    func build(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = [],
        analysisReason: String = "manual",
        schemaVersion: String = "record_aggregate.v1",
        clientVersion: String = "mory.v3"
    ) -> AnalyzeRequestPayload {
        AnalyzeRequestPayload(
            schemaVersion: schemaVersion,
            clientVersion: clientVersion,
            analysisReason: analysisReason,
            recordShell: .init(
                id: record.id.uuidString,
                createdAt: dateFormatter.string(from: record.createdAt),
                updatedAt: dateFormatter.string(from: record.updatedAt),
                rawText: record.rawText,
                captureSource: record.captureSource.rawValue,
                userMood: record.userMood,
                userIntensity: record.userIntensity,
                inputContext: record.inputContext
            ),
            artifacts: artifacts.map { artifact in
                .init(
                    id: artifact.id.uuidString,
                    kind: artifact.kind.rawValue,
                    title: artifact.title,
                    summary: artifact.summary,
                    textContent: artifact.textContent,
                    metadata: artifact.metadata
                )
            },
            knownEntities: knownEntities.map { entity in
                .init(
                    id: entity.id.uuidString,
                    kind: entity.kind.rawValue,
                    name: entity.name,
                    aliases: entity.aliases,
                    confidence: entity.confidence
                )
            }
        )
    }
}

struct AnalyzeRequestPayload: Codable, Sendable {
    struct RecordShellPayload: Codable, Sendable {
        var id: String
        var createdAt: String
        var updatedAt: String
        var rawText: String
        var captureSource: String
        var userMood: String?
        var userIntensity: Int?
        var inputContext: String?

        enum CodingKeys: String, CodingKey {
            case id
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case rawText = "raw_text"
            case captureSource = "capture_source"
            case userMood = "user_mood"
            case userIntensity = "user_intensity"
            case inputContext = "input_context"
        }
    }

    struct ArtifactPayload: Codable, Sendable {
        var id: String
        var kind: String
        var title: String
        var summary: String
        var textContent: String
        var metadata: [String: String]

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case title
            case summary
            case textContent = "text_content"
            case metadata
        }
    }

    struct KnownEntityPayload: Codable, Sendable {
        var id: String
        var kind: String
        var name: String
        var aliases: [String]
        var confidence: Double?
    }

    var schemaVersion: String
    var clientVersion: String
    var analysisReason: String
    var recordShell: RecordShellPayload
    var artifacts: [ArtifactPayload]
    var knownEntities: [KnownEntityPayload]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case clientVersion = "client_version"
        case analysisReason = "analysis_reason"
        case recordShell = "record_shell"
        case artifacts
        case knownEntities = "known_entities"
    }
}

import Foundation

struct AnalyzeResponseMapper {
    func map(recordID: UUID, response: AnalyzeResponseEnvelope, createdAt: Date = .now) -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: recordID,
            tags: normalizedTags(from: response),
            emotionLabel: response.emotion.label,
            insight: response.summary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? (response.summary ?? response.insight)
                : response.insight,
            followUpQuestion: response.followUp?.question,
            entities: inferEntities(from: response),
            createdAt: createdAt
        )
    }

    private func normalizedTags(from response: AnalyzeResponseEnvelope) -> [String] {
        var values = response.tags
        let themeEntities = response.entities
            .filter { $0.kind == "theme" }
            .map(\.name)
        values.append(contentsOf: themeEntities)
        return Array(NSOrderedSet(array: values)) as? [String] ?? values
    }

    private func inferEntities(from response: AnalyzeResponseEnvelope) -> [EntityReference] {
        var results = response.entities.compactMap(mapEntity)

        if results.isEmpty {
            results = response.tags.prefix(4).map {
                EntityReference(kind: .theme, name: $0, confidence: nil)
            }
        }

        return Array(results.prefix(8))
    }

    private func mapEntity(_ entity: AnalyzeResponseEnvelope.Entity) -> EntityReference? {
        guard let kind = EntityKind(rawValue: entity.kind.lowercased()) else { return nil }
        let name = entity.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return EntityReference(
            kind: kind,
            name: name,
            confidence: entity.confidence
        )
    }
}

struct AnalyzeResponseEnvelope: Codable, Sendable {
    struct Emotion: Codable, Sendable {
        var label: String
        var intensity: Int?
        var confidence: Double?
    }

    struct FollowUp: Codable, Sendable {
        var question: String
        var expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case question
            case expiresAt = "expires_at"
        }
    }

    struct Entity: Codable, Sendable {
        var kind: String
        var name: String
        var canonicalName: String?
        var confidence: Double?
        var sourceArtifactIDs: [String]?

        enum CodingKeys: String, CodingKey {
            case kind
            case name
            case canonicalName = "canonical_name"
            case confidence
            case sourceArtifactIDs = "source_artifact_ids"
        }
    }

    struct CandidateEdge: Codable, Sendable {
        var fromName: String
        var fromKind: String
        var toName: String
        var toKind: String
        var relation: String
        var confidence: Double?

        enum CodingKeys: String, CodingKey {
            case fromName = "from_name"
            case fromKind = "from_kind"
            case toName = "to_name"
            case toKind = "to_kind"
            case relation
            case confidence
        }
    }

    var tags: [String]
    var emotion: Emotion
    var entities: [Entity]
    var candidateEdges: [CandidateEdge]
    var insight: String
    var summary: String?
    var followUp: FollowUp?

    enum CodingKeys: String, CodingKey {
        case tags
        case emotion
        case entities
        case candidateEdges = "candidate_edges"
        case insight
        case summary
        case followUp = "follow_up"
    }
}

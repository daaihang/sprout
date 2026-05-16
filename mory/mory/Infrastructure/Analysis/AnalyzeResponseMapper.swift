import Foundation

struct AnalyzeResponseMapper {
    func map(recordID: UUID, response: AnalyzeResponseEnvelope, createdAt: Date = .now) -> RecordAnalysisSnapshot {
        RecordAnalysisSnapshot(
            recordID: recordID,
            summary: bestSummary(from: response),
            themes: normalizedThemes(from: response),
            emotionInterpretation: buildEmotionInterpretation(from: response),
            salienceScore: response.salienceScore ?? inferredSalienceScore(from: response),
            retrievalTerms: retrievalTerms(from: response),
            entityMentions: inferEntities(from: response),
            candidateEdges: inferCandidateEdges(from: response),
            followUpCandidates: inferFollowUpCandidates(from: response),
            reflectionHint: response.reflectionHint,
            createdAt: createdAt
        )
    }

    private func bestSummary(from response: AnalyzeResponseEnvelope) -> String {
        let primary = response.summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let primary, !primary.isEmpty { return primary }
        return response.insight.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedThemes(from response: AnalyzeResponseEnvelope) -> [String] {
        let themeEntities = response.entities
            .filter { $0.kind.lowercased() == EntityKind.theme.rawValue }
            .map(\.name)
        var values = themeEntities
        values.append(contentsOf: response.tags)
        return Array(NSOrderedSet(array: values.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })) as? [String] ?? values
    }

    private func buildEmotionInterpretation(from response: AnalyzeResponseEnvelope) -> String {
        if let interpretation = response.emotion.interpretation?.trimmingCharacters(in: .whitespacesAndNewlines), !interpretation.isEmpty {
            return interpretation
        }
        if let intensity = response.emotion.intensity {
            return "\(response.emotion.label) (intensity \(intensity))"
        }
        return response.emotion.label
    }

    private func inferredSalienceScore(from response: AnalyzeResponseEnvelope) -> Double {
        var score = 0.25
        score += min(Double(response.entities.count) * 0.08, 0.32)
        score += min(Double(response.candidateEdges.count) * 0.05, 0.20)
        score += min(Double(response.tags.count) * 0.03, 0.15)
        if response.followUp != nil { score += 0.08 }
        return min(score, 1)
    }

    private func retrievalTerms(from response: AnalyzeResponseEnvelope) -> [String] {
        let entityNames = response.entities.map(\.name)
        let values = response.retrievalTerms + response.tags + normalizedThemes(from: response) + entityNames
        return Array(
            NSOrderedSet(
                array: values.filter {
                    !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
                }
            )
        ) as? [String] ?? values
    }

    private func inferEntities(from response: AnalyzeResponseEnvelope) -> [EntityReference] {
        var results = response.entities.compactMap(mapEntity)
        if results.isEmpty {
            results = normalizedThemes(from: response).prefix(4).map {
                EntityReference(kind: .theme, name: $0)
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
            aliases: entity.aliases ?? [],
            confidence: entity.confidence
        )
    }

    private func inferCandidateEdges(from response: AnalyzeResponseEnvelope) -> [CandidateEntityEdge] {
        response.candidateEdges.compactMap { edge in
            guard
                let fromKind = EntityKind(rawValue: edge.fromKind.lowercased()),
                let toKind = EntityKind(rawValue: edge.toKind.lowercased()),
                let relationKind = mapRelationKind(edge.relation)
            else {
                return nil
            }

            return CandidateEntityEdge(
                from: EntityReference(kind: fromKind, name: edge.fromName),
                to: EntityReference(kind: toKind, name: edge.toName),
                relationKind: relationKind,
                confidence: edge.confidence
            )
        }
    }

    private func inferFollowUpCandidates(from response: AnalyzeResponseEnvelope) -> [FollowUpCandidate] {
        guard let followUp = response.followUp else { return [] }
        return [
            FollowUpCandidate(
                prompt: followUp.question,
                reason: followUp.reason
            )
        ]
    }

    private func mapRelationKind(_ rawValue: String) -> EntityRelationKind? {
        switch rawValue.lowercased() {
        case "mentioned_with", "mentionedwith":
            return .mentionedWith
        case "repeated_in", "repeatedin":
            return .repeatedIn
        case "decided_at", "decidedat":
            return .decidedAt
        case "related_to", "relatedto":
            return .relatedTo
        default:
            return nil
        }
    }
}

struct AnalyzeResponseEnvelope: Codable, Sendable {
    struct Emotion: Codable, Sendable {
        var label: String
        var intensity: Double?
        var confidence: Double?
        var interpretation: String?
    }

    struct FollowUp: Codable, Sendable {
        var question: String
        var reason: String?
        var expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case question
            case reason
            case expiresAt = "expires_at"
        }
    }

    struct Entity: Codable, Sendable {
        var kind: String
        var name: String
        var canonicalName: String?
        var aliases: [String]?
        var confidence: Double?
        var sourceArtifactIDs: [String]?

        enum CodingKeys: String, CodingKey {
            case kind
            case name
            case canonicalName = "canonical_name"
            case aliases
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
    var retrievalTerms: [String]
    var emotion: Emotion
    var entities: [Entity]
    var candidateEdges: [CandidateEdge]
    var insight: String
    var summary: String?
    var salienceScore: Double?
    var followUp: FollowUp?
    var reflectionHint: String?

    enum CodingKeys: String, CodingKey {
        case tags
        case retrievalTerms = "retrieval_terms"
        case emotion
        case entities
        case candidateEdges = "candidate_edges"
        case insight
        case summary
        case salienceScore = "salience_score"
        case followUp = "follow_up"
        case reflectionHint = "reflection_hint"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        retrievalTerms = try container.decodeIfPresent([String].self, forKey: .retrievalTerms) ?? []
        emotion = try container.decode(Emotion.self, forKey: .emotion)
        entities = try container.decodeIfPresent([Entity].self, forKey: .entities) ?? []
        candidateEdges = try container.decodeIfPresent([CandidateEdge].self, forKey: .candidateEdges) ?? []
        insight = try container.decode(String.self, forKey: .insight)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        salienceScore = try container.decodeIfPresent(Double.self, forKey: .salienceScore)
        followUp = try container.decodeIfPresent(FollowUp.self, forKey: .followUp)
        reflectionHint = try container.decodeIfPresent(String.self, forKey: .reflectionHint)
    }

    init(
        tags: [String],
        retrievalTerms: [String],
        emotion: Emotion,
        entities: [Entity],
        candidateEdges: [CandidateEdge],
        insight: String,
        summary: String?,
        salienceScore: Double?,
        followUp: FollowUp?,
        reflectionHint: String?
    ) {
        self.tags = tags
        self.retrievalTerms = retrievalTerms
        self.emotion = emotion
        self.entities = entities
        self.candidateEdges = candidateEdges
        self.insight = insight
        self.summary = summary
        self.salienceScore = salienceScore
        self.followUp = followUp
        self.reflectionHint = reflectionHint
    }
}

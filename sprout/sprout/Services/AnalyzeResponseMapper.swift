import Foundation

struct AnalyzeResponseMapper {
    func map(
        response: SproutAnalyzeResponse,
        recordID: UUID,
        createdAt: Date = .now
    ) -> RecordAnalysisSnapshot {
        let entities = mapEntities(response.entities)
        let tags = mergeTags(response.tags, entities: entities)
        let insight = preferredInsight(from: response)
        let retrievalTerms = mapRetrievalTerms(response.retrievalTerms, tags: tags, entities: entities)
        let followUpCandidates = mapFollowUpCandidates(response.followUp?.question)
        let candidateEdges = mapCandidateEdges(response.candidateEdges)

        return RecordAnalysisSnapshot(
            recordID: recordID,
            summary: insight,
            themes: tags,
            emotionInterpretation: normalizeText(response.emotion.label) ?? response.emotion.label,
            followUpCandidates: followUpCandidates,
            entityMentions: entities,
            salienceScore: response.salienceScore,
            retrievalTerms: retrievalTerms,
            reflectionHint: normalizeText(response.reflectionHint),
            candidateEdges: candidateEdges,
            createdAt: createdAt
        )
    }

    private func mapEntities(_ responseEntities: [SproutAnalyzeResponse.Entity]) -> [EntityReference] {
        var deduped: [EntityReference] = []
        var seenKeys: Set<String> = []

        for entity in responseEntities {
            guard let kind = normalizeKind(entity.kind) else { continue }
            let rawName = normalizeText(entity.canonicalName) ?? normalizeText(entity.name)
            guard let name = rawName, !name.isEmpty else { continue }

            let key = "\(kind.rawValue)::\(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))"
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)

            deduped.append(
                EntityReference(
                    kind: kind,
                    name: name,
                    confidence: entity.confidence
                )
            )
        }

        return deduped
    }

    private func mergeTags(_ rawTags: [String], entities: [EntityReference]) -> [String] {
        var ordered: [String] = []
        var seen: Set<String> = []

        for tag in rawTags {
            guard let normalized = normalizeText(tag) else { continue }
            appendUnique(normalized, to: &ordered, seen: &seen)
        }

        for theme in entities where theme.kind == .theme {
            appendUnique(theme.name, to: &ordered, seen: &seen)
        }

        return ordered
    }

    private func preferredInsight(from response: SproutAnalyzeResponse) -> String {
        normalizeText(response.summary)
            ?? normalizeText(response.insight)
            ?? response.insight
    }

    private func mapRetrievalTerms(
        _ rawTerms: [String],
        tags: [String],
        entities: [EntityReference]
    ) -> [String] {
        var ordered: [String] = []
        var seen: Set<String> = []

        for term in rawTerms {
            guard let normalized = normalizeText(term) else { continue }
            appendUnique(normalized, to: &ordered, seen: &seen)
        }

        for tag in tags {
            appendUnique(tag, to: &ordered, seen: &seen)
        }

        for entity in entities {
            appendUnique(entity.name, to: &ordered, seen: &seen)
        }

        return ordered
    }

    private func mapFollowUpCandidates(_ question: String?) -> [String] {
        guard let question = normalizeText(question) else { return [] }
        return [question]
    }

    private func mapCandidateEdges(
        _ rawEdges: [SproutAnalyzeResponse.CandidateEdge]
    ) -> [RecordAnalysisSnapshot.CandidateEdge] {
        rawEdges.compactMap { edge in
            guard
                let fromName = normalizeText(edge.fromName),
                let fromKind = normalizeText(edge.fromKind),
                let toName = normalizeText(edge.toName),
                let toKind = normalizeText(edge.toKind),
                let relation = normalizeText(edge.relation)
            else {
                return nil
            }

            return RecordAnalysisSnapshot.CandidateEdge(
                fromName: fromName,
                fromKind: fromKind.lowercased(),
                toName: toName,
                toKind: toKind.lowercased(),
                relation: relation
            )
        }
    }

    private func appendUnique(_ value: String, to ordered: inout [String], seen: inout Set<String>) {
        let key = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !seen.contains(key) else { return }
        seen.insert(key)
        ordered.append(value)
    }

    private func normalizeKind(_ rawValue: String) -> EntityKind? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "person", "people", "human":
            return .person
        case "place", "location", "city", "area":
            return .place
        case "theme", "tag", "topic":
            return .theme
        case "decision", "choice", "plan":
            return .decision
        default:
            return EntityKind(rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }

    private func normalizeText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

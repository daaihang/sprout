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
            guard let name = sanitizedEntityName(rawName, kind: kind), !name.isEmpty else { continue }

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
                let fromName = sanitizeEdgeEndpoint(edge.fromName, kindText: edge.fromKind),
                let fromKind = normalizeText(edge.fromKind),
                let toName = sanitizeEdgeEndpoint(edge.toName, kindText: edge.toKind),
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

    private func sanitizedEntityName(_ text: String?, kind: EntityKind) -> String? {
        guard let normalized = normalizeText(text) else { return nil }
        let collapsed = normalized.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let wordCount = collapsed.split(whereSeparator: \.isWhitespace).count
        let sentenceLikeMarkers = ["。", "，", ",", " but ", " and ", " because ", "还是", "想到", "今天"]

        if collapsed.count > 48 { return nil }
        if wordCount > 6 { return nil }
        if sentenceLikeMarkers.contains(where: { collapsed.localizedCaseInsensitiveContains($0) }) { return nil }

        if kind == .decision {
            let lowered = collapsed.lowercased()
            if lowered.hasPrefix("i ") || lowered.hasPrefix("we ") {
                return nil
            }
        }

        return collapsed
    }

    private func sanitizeEdgeEndpoint(_ text: String?, kindText: String?) -> String? {
        guard let kind = kindText.flatMap(normalizeKind) else {
            return normalizeText(text)
        }
        return sanitizedEntityName(text, kind: kind)
    }
}

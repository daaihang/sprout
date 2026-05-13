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

        return RecordAnalysisSnapshot(
            recordID: recordID,
            tags: tags,
            emotionLabel: normalizeText(response.emotion.label) ?? response.emotion.label,
            insight: insight,
            followUpQuestion: normalizeText(response.followUp?.question),
            entities: entities,
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

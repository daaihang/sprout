import Foundation

struct LocalRecordAnalysisService {
    private let requestBuilder = AnalyzeRequestBuilder()
    private let responseMapper = AnalyzeResponseMapper()

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = []
    ) -> RecordAnalysisSnapshot {
        let request = requestBuilder.build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: "local_heuristic"
        )
        let response = synthesizeResponse(
            request: request,
            record: record,
            artifacts: artifacts
        )
        return responseMapper.map(
            recordID: record.id,
            response: response,
            createdAt: record.updatedAt
        )
    }

    private func synthesizeResponse(
        request: AnalyzeRequestPayload,
        record: RecordShell,
        artifacts: [Artifact]
    ) -> AnalyzeResponseEnvelope {
        let corpus = buildCorpus(record: record, artifacts: artifacts)
        let loweredCorpus = corpus.lowercased()
        let moodLabel = record.userMood?.trimmingCharacters(in: .whitespacesAndNewlines)
        let themes = inferredThemes(from: loweredCorpus, artifacts: artifacts)
        let entities = inferredEntities(from: corpus, loweredCorpus: loweredCorpus, themes: themes, artifacts: artifacts)
        let tags = inferredTags(record: record, artifacts: artifacts, themes: themes)
        let candidateEdges = inferredCandidateEdges(from: entities, themes: themes)
        let followUp = inferredFollowUp(from: artifacts, themes: themes)
        let summary = request.recordShell.rawText.trimmedPreview(maxLength: 180)
        let insight = buildInsight(summary: summary, themes: themes, entities: entities)
        let emotion = inferredEmotion(from: loweredCorpus, moodLabel: moodLabel)

        return AnalyzeResponseEnvelope(
            tags: tags,
            themes: themes,
            retrievalTerms: inferredRetrievalTerms(from: summary, themes: themes, entities: entities, tags: tags),
            emotion: emotion,
            entities: entities,
            candidateEdges: candidateEdges,
            insight: insight,
            summary: summary,
            salienceScore: inferredSalienceScore(artifactCount: artifacts.count, entityCount: entities.count, themeCount: themes.count),
            followUp: followUp,
            reflectionHint: buildReflectionHint(themes: themes, entities: entities)
        )
    }

    private func buildCorpus(record: RecordShell, artifacts: [Artifact]) -> String {
        ([record.rawText] + artifacts.map(\.summary) + artifacts.map(\.textContent))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }

    private func inferredThemes(from corpus: String, artifacts: [Artifact]) -> [String] {
        var themes: [String] = []

        let themeRules: [(String, [String])] = [
            ("career planning", ["career", "project", "quarter", "plan", "planning", "work"]),
            ("relationships", ["friend", "partner", "family", "dinner", "conversation", "together"]),
            ("transition", ["train", "station", "walk", "travel", "commute", "move", "shift"]),
            ("weather", ["rain", "storm", "sunny", "weather", "humid", "cloud"]),
            ("decision", ["decision", "decide", "choose", "chose", "option"]),
            ("execution", ["todo", "task", "deadline", "finish", "ship", "next step"]),
        ]

        for (theme, keywords) in themeRules where keywords.contains(where: { corpus.contains($0) }) {
            themes.append(theme)
        }

        if artifacts.contains(where: { $0.kind == .location }) {
            themes.append("place memory")
        }
        if artifacts.contains(where: { $0.kind == .photo }) {
            themes.append("visual capture")
        }
        if artifacts.contains(where: { $0.kind == .audio }) {
            themes.append("voice note")
        }
        if artifacts.contains(where: { $0.kind == .link }) {
            themes.append("reference")
        }
        if artifacts.contains(where: { $0.kind == .note }) {
            themes.append("planning")
        }

        if themes.isEmpty {
            themes.append("daily life")
        }

        return themes.uniquedPreservingOrder()
    }

    private func inferredEntities(
        from corpus: String,
        loweredCorpus: String,
        themes: [String],
        artifacts: [Artifact]
    ) -> [AnalyzeResponseEnvelope.Entity] {
        var entities: [AnalyzeResponseEnvelope.Entity] = []

        let people = extractCapitalizedCandidates(from: corpus)
        entities.append(contentsOf: people.prefix(3).map {
            AnalyzeResponseEnvelope.Entity(
                kind: EntityKind.person.rawValue,
                name: $0,
                canonicalName: $0,
                aliases: [],
                confidence: 0.84,
                sourceArtifactIDs: nil
            )
        })

        let placeTerms = [
            "station": "Station",
            "office": "Office",
            "home": "Home",
            "cafe": "Cafe",
            "airport": "Airport",
            "park": "Park",
        ]
        for (needle, displayName) in placeTerms where loweredCorpus.contains(needle) {
            entities.append(
                AnalyzeResponseEnvelope.Entity(
                    kind: EntityKind.place.rawValue,
                    name: displayName,
                    canonicalName: displayName,
                    aliases: [],
                    confidence: 0.72,
                    sourceArtifactIDs: nil
                )
            )
        }

        if let locationArtifact = artifacts.first(where: { $0.kind == .location }) {
            let locationName = locationArtifact.title.trimmedNonEmpty ?? locationArtifact.summary.trimmedNonEmpty ?? "Captured Location"
            entities.append(
                AnalyzeResponseEnvelope.Entity(
                    kind: EntityKind.place.rawValue,
                    name: locationName,
                    canonicalName: locationName,
                    aliases: [],
                    confidence: 0.76,
                    sourceArtifactIDs: [locationArtifact.id.uuidString]
                )
            )
        }

        entities.append(contentsOf: themes.prefix(3).map {
            AnalyzeResponseEnvelope.Entity(
                kind: EntityKind.theme.rawValue,
                name: $0,
                canonicalName: $0,
                aliases: [],
                confidence: 0.78,
                sourceArtifactIDs: nil
            )
        })

        return entities
            .deduplicatedEntities()
            .prefix(8)
            .map { $0 }
    }

    private func extractCapitalizedCandidates(from corpus: String) -> [String] {
        let pattern = #"\b[A-Z][a-z]{2,}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsrange = NSRange(corpus.startIndex..<corpus.endIndex, in: corpus)
        let stopWords = Set(["The", "This", "That", "With", "After", "Before", "Today", "Yesterday", "Tomorrow", "Untitled"])

        return regex.matches(in: corpus, range: nsrange)
            .compactMap { Range($0.range, in: corpus).map { String(corpus[$0]) } }
            .filter { !stopWords.contains($0) }
            .uniquedPreservingOrder()
    }

    private func inferredTags(record: RecordShell, artifacts: [Artifact], themes: [String]) -> [String] {
        var tags = artifacts.map { $0.kind.rawValue }
        if let mood = record.userMood?.trimmedNonEmpty {
            tags.append(mood.lowercased())
        }
        tags.append(contentsOf: themes)
        return tags.uniquedPreservingOrder()
    }

    private func inferredCandidateEdges(
        from entities: [AnalyzeResponseEnvelope.Entity],
        themes: [String]
    ) -> [AnalyzeResponseEnvelope.CandidateEdge] {
        let people = entities.filter { $0.kind == EntityKind.person.rawValue }
        let places = entities.filter { $0.kind == EntityKind.place.rawValue }
        let themeEntities = entities.filter { $0.kind == EntityKind.theme.rawValue }

        var edges: [AnalyzeResponseEnvelope.CandidateEdge] = []

        if let person = people.first, let theme = themeEntities.first {
            edges.append(
                .init(
                    fromName: person.name,
                    fromKind: person.kind,
                    toName: theme.name,
                    toKind: theme.kind,
                    relation: "mentioned_with",
                    confidence: 0.68
                )
            )
        }

        if let place = places.first, let theme = themeEntities.first {
            edges.append(
                .init(
                    fromName: place.name,
                    fromKind: place.kind,
                    toName: theme.name,
                    toKind: theme.kind,
                    relation: "repeated_in",
                    confidence: 0.61
                )
            )
        }

        if themes.contains("decision"), let person = people.first {
            edges.append(
                .init(
                    fromName: person.name,
                    fromKind: person.kind,
                    toName: "decision",
                    toKind: EntityKind.decision.rawValue,
                    relation: "decided_at",
                    confidence: 0.57
                )
            )
        }

        return edges.uniquedCandidateEdges()
    }

    private func inferredFollowUp(from artifacts: [Artifact], themes: [String]) -> AnalyzeResponseEnvelope.FollowUp? {
        if let todo = artifacts.first(where: { $0.kind == .note }) {
            return .init(
                question: "Revisit: \(todo.title)",
                reason: todo.summary.trimmedNonEmpty ?? "This note looks actionable.",
                expiresAt: nil
            )
        }

        if let firstTheme = themes.first {
            return .init(
                question: "Capture the next concrete step for \(firstTheme).",
                reason: "This memory suggests a thread worth continuing.",
                expiresAt: nil
            )
        }

        return nil
    }

    private func buildInsight(
        summary: String,
        themes: [String],
        entities: [AnalyzeResponseEnvelope.Entity]
    ) -> String {
        let themeText = themes.prefix(2).joined(separator: ", ")
        let entityText = entities.prefix(2).map(\.name).joined(separator: ", ")

        if !themeText.isEmpty && !entityText.isEmpty {
            return "\(summary) Key threads: \(themeText). Anchors: \(entityText)."
        }
        if !themeText.isEmpty {
            return "\(summary) Key threads: \(themeText)."
        }
        return summary
    }

    private func inferredEmotion(from corpus: String, moodLabel: String?) -> AnalyzeResponseEnvelope.Emotion {
        if let moodLabel, !moodLabel.isEmpty {
            return .init(label: moodLabel, intensity: 3, confidence: 0.7, interpretation: "\(moodLabel.capitalized) was explicit in the capture.")
        }

        if corpus.contains("frustrat") || corpus.contains("stress") {
            return .init(label: "tense", intensity: 3, confidence: 0.62, interpretation: "The capture contains signs of friction or pressure.")
        }
        if corpus.contains("excited") || corpus.contains("energ") {
            return .init(label: "energized", intensity: 4, confidence: 0.64, interpretation: "The capture points to momentum and forward energy.")
        }
        if corpus.contains("quiet") || corpus.contains("reflect") || corpus.contains("walk") {
            return .init(label: "reflective", intensity: 2, confidence: 0.66, interpretation: "The capture reads as slowed down and reflective.")
        }

        return .init(label: "neutral", intensity: 2, confidence: 0.5, interpretation: "No strong explicit emotional signal was detected.")
    }

    private func inferredRetrievalTerms(
        from summary: String,
        themes: [String],
        entities: [AnalyzeResponseEnvelope.Entity],
        tags: [String]
    ) -> [String] {
        let summaryTerms = summary
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        return (entities.map(\.name) + themes + tags + summaryTerms)
            .uniquedPreservingOrder()
            .prefix(12)
            .map { $0 }
    }

    private func inferredSalienceScore(artifactCount: Int, entityCount: Int, themeCount: Int) -> Double {
        min(0.35 + Double(artifactCount) * 0.08 + Double(entityCount) * 0.07 + Double(themeCount) * 0.05, 0.92)
    }

    private func buildReflectionHint(themes: [String], entities: [AnalyzeResponseEnvelope.Entity]) -> String? {
        guard let theme = themes.first else { return nil }
        if let entity = entities.first {
            return "This may grow into a reflection about \(theme) around \(entity.name)."
        }
        return "This may grow into a reflection about \(theme)."
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    func trimmedPreview(maxLength: Int) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count > maxLength else { return value }
        let index = value.index(value.startIndex, offsetBy: maxLength)
        return String(value[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == AnalyzeResponseEnvelope.Entity {
    func deduplicatedEntities() -> [Element] {
        var seen = Set<String>()
        return filter { entity in
            seen.insert("\(entity.kind.lowercased())::\(entity.name.lowercased())").inserted
        }
    }
}

private extension Array where Element == AnalyzeResponseEnvelope.CandidateEdge {
    func uniquedCandidateEdges() -> [Element] {
        var seen = Set<String>()
        return filter { edge in
            seen.insert("\(edge.fromKind)::\(edge.fromName)::\(edge.relation)::\(edge.toKind)::\(edge.toName)").inserted
        }
    }
}

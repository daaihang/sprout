import Foundation

struct SproutMemoryAggregateBuilder {
    func buildPreviewAggregate(from text: String) -> SproutMemoryAggregate {
        let now = Date()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let artifact = Artifact(
            kind: .text,
            title: previewTitle(from: trimmed),
            summary: trimmed,
            textContent: trimmed,
            createdAt: now,
            updatedAt: now
        )
        let record = RecordShell(
            createdAt: now,
            updatedAt: now,
            rawText: trimmed,
            captureSource: .composer,
            artifactIDs: [artifact.id]
        )
        return SproutMemoryAggregate(
            recordShell: record,
            artifacts: [artifact],
            knownEntities: []
        )
    }

    func build(record: Record) -> SproutMemoryAggregate {
        let artifacts = buildArtifacts(record: record)
        let knownEntities = (record.mentionedPeople ?? []).map {
            EntityReference(kind: .person, name: $0.displayName, confidence: nil)
        }
        let recordShell = RecordShell(
            id: record.id,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            rawText: record.body,
            captureSource: .composer,
            artifactIDs: artifacts.map(\.id),
            userMood: record.mood,
            userIntensity: record.intensity
        )
        return SproutMemoryAggregate(
            recordShell: recordShell,
            artifacts: artifacts,
            knownEntities: knownEntities
        )
    }

    private func buildArtifacts(record: Record) -> [Artifact] {
        var artifacts: [Artifact] = []

        if !record.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            artifacts.append(
                Artifact(
                    kind: .text,
                    title: previewTitle(from: record.body),
                    summary: record.body,
                    textContent: record.body,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt
                )
            )
        }

        for media in (record.mediaCards ?? []).sorted(by: { $0.sortIndex < $1.sortIndex }) {
            if let artifact = artifact(from: media, record: record) {
                artifacts.append(artifact)
            }
        }

        if let location = record.location, !location.isEmpty {
            artifacts.append(
                Artifact(
                    kind: .location,
                    title: location,
                    summary: location,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    metadata: [
                        "latitude": record.latitude.map(String.init) ?? "",
                        "longitude": record.longitude.map(String.init) ?? ""
                    ].filter { !$0.value.isEmpty }
                )
            )
        }

        if let weather = record.weather, !weather.isEmpty {
            artifacts.append(
                Artifact(
                    kind: .weather,
                    title: weather,
                    summary: "\(weather) \(record.temperature.map { String(format: "%.0f", $0) } ?? "")".trimmingCharacters(in: .whitespaces),
                    createdAt: record.weatherObservedAt ?? record.createdAt,
                    updatedAt: record.updatedAt,
                    metadata: [
                        "location": record.location ?? "",
                        "humidity": record.humidity.map(String.init) ?? ""
                    ].filter { !$0.value.isEmpty }
                )
            )
        }

        if let people = record.mentionedPeople, !people.isEmpty {
            artifacts.append(contentsOf: people.map { person in
                Artifact(
                    kind: .personMention,
                    title: person.displayName,
                    summary: person.secondaryLabel,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    metadata: ["relationship": person.relationship ?? ""].filter { !$0.value.isEmpty },
                    entities: [EntityReference(kind: .person, name: person.displayName, confidence: nil)]
                )
            })
        }

        if let decisions = record.linkedDecisions, !decisions.isEmpty {
            artifacts.append(contentsOf: decisions.map { decision in
                Artifact(
                    kind: .decisionNote,
                    title: decision.title,
                    summary: decision.context ?? decision.outcome ?? decision.status,
                    textContent: [decision.context, decision.outcome].compactMap { $0 }.joined(separator: "\n"),
                    createdAt: decision.createdAt,
                    updatedAt: decision.updatedAt,
                    metadata: ["status": decision.status],
                    entities: [EntityReference(kind: .decision, name: decision.title, confidence: nil)]
                )
            })
        }

        return artifacts
    }

    private func artifact(from media: MediaCard, record: Record) -> Artifact? {
        let kind: ArtifactKind
        switch media.type {
        case "photo":
            kind = .photo
        case "audio":
            kind = .audio
        case "music":
            kind = .music
        case "link":
            kind = .link
        case "todo":
            kind = .todo
        default:
            return nil
        }

        return Artifact(
            id: media.id,
            kind: kind,
            title: media.title ?? media.locationName ?? record.body.prefix(24).description,
            summary: media.caption ?? media.locationName ?? "",
            textContent: media.aiDescription ?? "",
            createdAt: media.capturedAt ?? media.createdAt,
            updatedAt: record.updatedAt,
            metadata: [
                "url": media.url ?? "",
                "albumName": media.albumName ?? "",
                "artworkURLString": media.artworkURLString ?? "",
                "locationName": media.locationName ?? ""
            ].filter { !$0.value.isEmpty }
        )
    }

    private func previewTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Memory" }
        return String(trimmed.prefix(32))
    }
}

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
            var metadata: [String: String] = [:]
            if let latitude = record.latitude {
                metadata["latitude"] = String(latitude)
            }
            if let longitude = record.longitude {
                metadata["longitude"] = String(longitude)
            }

            let locationArtifact = Artifact(
                kind: .location,
                title: location,
                summary: location,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                metadata: metadata
            )
            artifacts.append(
                locationArtifact
            )
        }

        if let weather = record.weather, !weather.isEmpty {
            let temperatureText: String
            if let temperature = record.temperature {
                temperatureText = String(format: "%.0f", temperature)
            } else {
                temperatureText = ""
            }
            let weatherSummary = "\(weather) \(temperatureText)".trimmingCharacters(in: .whitespaces)
            var metadata: [String: String] = [:]
            if let location = record.location, !location.isEmpty {
                metadata["location"] = location
            }
            if let humidity = record.humidity {
                metadata["humidity"] = String(humidity)
            }

            let weatherArtifact = Artifact(
                kind: .weather,
                title: weather,
                summary: weatherSummary,
                createdAt: record.weatherObservedAt ?? record.createdAt,
                updatedAt: record.updatedAt,
                metadata: metadata
            )
            artifacts.append(
                weatherArtifact
            )
        }

        if let people = record.mentionedPeople, !people.isEmpty {
            let peopleArtifacts = people.map { person in
                var metadata: [String: String] = [:]
                if let relationship = person.relationship, !relationship.isEmpty {
                    metadata["relationship"] = relationship
                }

                return Artifact(
                    kind: .personMention,
                    title: person.displayName,
                    summary: person.secondaryLabel,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt,
                    metadata: metadata,
                    entities: [EntityReference(kind: .person, name: person.displayName, confidence: nil)]
                )
            }
            artifacts.append(contentsOf: peopleArtifacts)
        }

        if let decisions = record.linkedDecisions, !decisions.isEmpty {
            let decisionArtifacts = decisions.map { decision in
                let summary = decision.context ?? decision.outcome ?? decision.status
                let textContent = [decision.context, decision.outcome]
                    .compactMap { $0 }
                    .joined(separator: "\n")

                return Artifact(
                    kind: .decisionNote,
                    title: decision.title,
                    summary: summary,
                    textContent: textContent,
                    createdAt: decision.createdAt,
                    updatedAt: decision.updatedAt,
                    metadata: ["status": decision.status],
                    entities: [EntityReference(kind: .decision, name: decision.title, confidence: nil)]
                )
            }
            artifacts.append(contentsOf: decisionArtifacts)
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

        let fallbackTitle = String(record.body.prefix(24))
        let title = media.title ?? media.locationName ?? fallbackTitle
        let summary = media.caption ?? media.locationName ?? ""
        var metadata: [String: String] = [:]
        if let url = media.url, !url.isEmpty {
            metadata["url"] = url
        }
        if let albumName = media.albumName, !albumName.isEmpty {
            metadata["albumName"] = albumName
        }
        if let artworkURLString = media.artworkURLString, !artworkURLString.isEmpty {
            metadata["artworkURLString"] = artworkURLString
        }
        if let locationName = media.locationName, !locationName.isEmpty {
            metadata["locationName"] = locationName
        }

        return Artifact(
            id: media.id,
            kind: kind,
            title: title,
            summary: summary,
            textContent: media.aiDescription ?? "",
            createdAt: media.capturedAt ?? media.createdAt,
            updatedAt: record.updatedAt,
            metadata: metadata
        )
    }

    private func previewTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Memory" }
        return String(trimmed.prefix(32))
    }
}

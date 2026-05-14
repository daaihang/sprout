import Foundation
import CoreLocation

struct SproutMemoryAggregateBuilder {
    func buildPreviewAggregate(from text: String) -> SproutMemoryAggregate {
        let now = Date()
        return build(
            draft: CaptureDraft(textArtifactText: text),
            createdAt: now,
            captureSource: .composer,
            parsed: RecordParser.parseBody(text)
        )
    }

    func build(
        draft: CaptureDraft,
        createdAt: Date,
        captureSource: CaptureSource,
        parsed: ParsedContent? = nil,
        photoPayloads: [PreparedPhotoMedia] = []
    ) -> SproutMemoryAggregate {
        let trimmed = draft.trimmedTextArtifactText
        let parsedContent = parsed ?? RecordParser.parseBody(trimmed)
        let artifacts = buildArtifacts(
            draft: draft,
            createdAt: createdAt,
            parsed: parsedContent,
            photoPayloads: photoPayloads
        )
        let knownEntities = draft.attachments.people.map {
            EntityReference(kind: .person, name: $0.displayName, confidence: nil)
        }

        return SproutMemoryAggregate(
            recordShell: RecordShell(
                createdAt: createdAt,
                updatedAt: createdAt,
                rawText: trimmed,
                captureSource: captureSource,
                artifactIDs: artifacts.map(\.id),
                userMood: draft.attachments.mood?.rawValue,
                userIntensity: draft.attachments.mood == nil ? nil : draft.attachments.intensity
            ),
            artifacts: artifacts,
            knownEntities: knownEntities
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

    func buildStandaloneAggregate(
        cardType: RecordCardKind,
        recordID: UUID = UUID(),
        createdAt: Date,
        textArtifactText: String = "",
        emotion: EmotionCardData? = nil,
        weather: WeatherCardData? = nil,
        location: MapCardData? = nil,
        music: MusicCardData? = nil,
        todo: TodoCardData? = nil,
        photoPayloads: [PreparedPhotoMedia] = [],
        audioData: Data? = nil
    ) -> SproutMemoryAggregate {
        let trimmed = textArtifactText.trimmingCharacters(in: .whitespacesAndNewlines)
        var artifacts: [Artifact] = []

        if !trimmed.isEmpty {
            artifacts.append(
                Artifact(
                    kind: .text,
                    title: previewTitle(from: trimmed),
                    summary: trimmed,
                    textContent: trimmed,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            )
        }

        switch cardType {
        case .text:
            break
        case .emotion:
            if let emotion {
                artifacts.append(
                    Artifact(
                        kind: .text,
                        title: emotion.mood.label,
                        summary: emotion.note.isEmpty ? emotion.mood.label : emotion.note,
                        textContent: emotion.note,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        metadata: [
                            "mood": emotion.mood.rawValue,
                            "intensity": String(emotion.intensity)
                        ]
                    )
                )
            }
        case .weather:
            if let weather {
                var metadata: [String: String] = [
                    "condition": weather.condition.rawValue,
                    "humidity": String(weather.humidity),
                    "source": weather.source.rawValue
                ]
                if let coordinate = weather.coordinate {
                    metadata["latitude"] = String(coordinate.latitude)
                    metadata["longitude"] = String(coordinate.longitude)
                }
                artifacts.append(
                    Artifact(
                        kind: .weather,
                        title: weather.condition.label,
                        summary: weather.location.isEmpty ? weather.condition.label : weather.location,
                        textContent: weather.liveSummary ?? "",
                        createdAt: weather.observedAt ?? createdAt,
                        updatedAt: createdAt,
                        metadata: metadata
                    )
                )
            }
        case .activity:
            break
        case .todo:
            if let todo, !todo.isEmpty {
                let textContent = (try? JSONEncoder().encode(todo.items))
                    .flatMap { String(data: $0, encoding: .utf8) } ?? ""
                artifacts.append(
                    Artifact(
                        kind: .todo,
                        title: todo.title.isEmpty ? "To-Do" : todo.title,
                        summary: "\(todo.doneCount) of \(todo.totalCount) done",
                        textContent: textContent,
                        createdAt: createdAt,
                        updatedAt: createdAt
                    )
                )
            }
        case .photo:
            for (index, payload) in photoPayloads.enumerated() {
                artifacts.append(
                    Artifact(
                        id: payload.id,
                        kind: .photo,
                        title: photoPayloads.count <= 1 ? "Photo" : "Photo \(index + 1)",
                        summary: trimmed.isEmpty ? "Captured photo" : previewTitle(from: trimmed),
                        textContent: "",
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        metadata: ["source": "add_card"],
                        binaryPayload: payload.imageData,
                        previewPayload: payload.thumbnailData
                    )
                )
            }
        case .music:
            if let music, !music.isEmpty {
                var metadata: [String: String] = [:]
                if let url = music.appleMusicURL?.absoluteString {
                    metadata["url"] = url
                }
                if !music.albumName.isEmpty {
                    metadata["albumName"] = music.albumName
                }
                if let artworkURL = music.albumArtworkURL?.absoluteString {
                    metadata["artworkURLString"] = artworkURL
                }
                artifacts.append(
                    Artifact(
                        kind: .music,
                        title: music.trackName,
                        summary: music.artistName,
                        textContent: music.albumName,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        metadata: metadata
                    )
                )
            }
        case .link:
            break
        case .map:
            if let location {
                var metadata: [String: String] = [:]
                if let coordinate = location.coordinate {
                    metadata["latitude"] = String(coordinate.latitude)
                    metadata["longitude"] = String(coordinate.longitude)
                }
                artifacts.append(
                    Artifact(
                        kind: .location,
                        title: location.locationName.isEmpty ? "Location" : location.locationName,
                        summary: location.descriptionText.isEmpty ? location.locationName : location.descriptionText,
                        textContent: location.descriptionText,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        metadata: metadata
                    )
                )
            }
        case .audio:
            if let audioData {
                artifacts.append(
                    Artifact(
                        kind: .audio,
                        title: "Voice",
                        summary: trimmed.isEmpty ? "Voice note" : previewTitle(from: trimmed),
                        textContent: trimmed,
                        createdAt: createdAt,
                        updatedAt: createdAt,
                        metadata: ["byteCount": String(audioData.count)],
                        binaryPayload: audioData
                    )
                )
            }
        case .people:
            break
        case .todayInHistory, .book, .film, .game, .ticket, .health:
            break
        case .quote:
            break
        }

        let knownEntities: [EntityReference] = []
        return SproutMemoryAggregate(
            recordShell: RecordShell(
                id: recordID,
                createdAt: createdAt,
                updatedAt: createdAt,
                rawText: trimmed,
                captureSource: .manual,
                artifactIDs: artifacts.map(\.id),
                userMood: emotion?.mood.rawValue,
                userIntensity: emotion?.intensity
            ),
            artifacts: artifacts,
            knownEntities: knownEntities
        )
    }

    private func buildArtifacts(
        draft: CaptureDraft,
        createdAt: Date,
        parsed: ParsedContent,
        photoPayloads: [PreparedPhotoMedia]
    ) -> [Artifact] {
        var artifacts: [Artifact] = []
        let trimmed = draft.trimmedTextArtifactText

        if !trimmed.isEmpty {
            artifacts.append(
                Artifact(
                    kind: .text,
                    title: previewTitle(from: trimmed),
                    summary: trimmed,
                    textContent: trimmed,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            )
        }

        for (index, payload) in photoPayloads.enumerated() {
            artifacts.append(
                Artifact(
                    id: payload.id,
                    kind: .photo,
                    title: photoTitle(index: index, totalCount: photoPayloads.count),
                    summary: photoSummary(from: trimmed),
                    textContent: "",
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: [
                        "payloadIndex": String(index),
                        "source": "composer"
                    ],
                    binaryPayload: payload.imageData,
                    previewPayload: payload.thumbnailData
                )
            )
        }

        if let location = draft.attachments.locationData, !location.locationName.isEmpty || location.coordinate != nil {
            var metadata: [String: String] = [:]
            if let coordinate = location.coordinate {
                metadata["latitude"] = String(coordinate.latitude)
                metadata["longitude"] = String(coordinate.longitude)
            }
            artifacts.append(
                Artifact(
                    kind: .location,
                    title: location.locationName.isEmpty ? "Location" : location.locationName,
                    summary: location.descriptionText.isEmpty ? (location.locationName.isEmpty ? "Location" : location.locationName) : location.descriptionText,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: metadata
                )
            )
        }

        if let music = draft.attachments.music, !music.isEmpty {
            var metadata: [String: String] = [:]
            if let url = music.appleMusicURL?.absoluteString {
                metadata["url"] = url
            }
            if !music.albumName.isEmpty {
                metadata["albumName"] = music.albumName
            }
            if let artworkURL = music.albumArtworkURL?.absoluteString {
                metadata["artworkURLString"] = artworkURL
            }
            artifacts.append(
                Artifact(
                    kind: .music,
                    title: music.trackName.isEmpty ? "Music" : music.trackName,
                    summary: music.artistName.isEmpty ? music.albumName : music.artistName,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: metadata
                )
            )
        }

        if let todos = draft.attachments.todos, !todos.items.isEmpty {
            let summary = "\(todos.doneCount) of \(todos.totalCount) done"
            let textContent = (try? JSONEncoder().encode(todos.items))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
            artifacts.append(
                Artifact(
                    kind: .todo,
                    title: todos.title.isEmpty ? "To-Do" : todos.title,
                    summary: summary,
                    textContent: textContent,
                    createdAt: createdAt,
                    updatedAt: createdAt
                )
            )
        }

        if let audioData = draft.attachments.audioData {
            artifacts.append(
                Artifact(
                    kind: .audio,
                    title: "Voice",
                    summary: trimmed.isEmpty ? "Voice note" : previewTitle(from: trimmed),
                    textContent: trimmed,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: [
                        "byteCount": String(audioData.count)
                    ],
                    binaryPayload: audioData
                )
            )
        }

        if !draft.attachments.people.isEmpty {
            let personArtifacts = draft.attachments.people.map { person in
                var metadata: [String: String] = [:]
                if let relationship = person.relationship, !relationship.isEmpty {
                    metadata["relationship"] = relationship
                }
                return Artifact(
                    kind: .personMention,
                    title: person.displayName,
                    summary: person.secondaryLabel,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: metadata,
                    entities: [EntityReference(kind: .person, name: person.displayName, confidence: nil)]
                )
            }
            artifacts.append(contentsOf: personArtifacts)
        }

        if !parsed.appleMusicURLs.isEmpty {
            let parsedMusicArtifacts = parsed.appleMusicURLs.map { url in
                Artifact(
                    kind: .music,
                    title: url.lastPathComponent.replacingOccurrences(of: "-", with: " "),
                    summary: url.host ?? url.absoluteString,
                    textContent: url.absoluteString,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: ["url": url.absoluteString]
                )
            }
            artifacts.append(contentsOf: parsedMusicArtifacts)
        }

        if !parsed.regularURLs.isEmpty {
            let parsedLinkArtifacts = parsed.regularURLs.map { url in
                Artifact(
                    kind: .link,
                    title: url.host ?? url.absoluteString,
                    summary: url.absoluteString,
                    textContent: url.absoluteString,
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    metadata: ["url": url.absoluteString]
                )
            }
            artifacts.append(contentsOf: parsedLinkArtifacts)
        }

        return artifacts
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

    private func photoTitle(index: Int, totalCount: Int) -> String {
        totalCount <= 1 ? "Photo" : "Photo \(index + 1)"
    }

    private func photoSummary(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Captured photo" : previewTitle(from: trimmed)
    }

    private func artifact(from media: MediaCard, record: Record) -> Artifact? {
        guard let mediaKind = media.mediaKind else { return nil }
        let kind = mediaKind.artifactKind

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
            metadata: metadata,
            binaryPayload: media.imageData ?? media.audioData,
            previewPayload: media.thumbnailData
        )
    }

    private func previewTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Untitled Memory" }
        return String(trimmed.prefix(32))
    }
}

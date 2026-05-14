import SwiftUI
import MapKit

@MainActor
struct ArtifactRenderer {
    func renderCard(
        for artifact: Artifact,
        record: Record,
        focusedSection: RecordSection,
        fallbackID: String,
        fallbackSpanKey: String
    ) -> RenderedArtifactCard? {
        switch artifact.kind {
        case .text:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "text",
                section: .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .link:
            guard let urlString = artifact.metadata["url"] ?? nonEmpty(artifact.textContent),
                  let url = URL(string: urlString) else {
                return renderedArtifactCard(
                    id: fallbackID,
                    spanKey: fallbackSpanKey,
                    presentationKey: "link",
                    section: .link,
                    record: record,
                    cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
                )
            }
            let data = LinkCardData(
                links: [
                    LinkItem(
                        url: url,
                        title: artifact.title,
                        description: artifact.summary
                    )
                ]
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "link",
                section: .link,
                record: record,
                cardView: AnyView(LinkCard(data: data))
            )
        case .todo:
            let items = decodeTodoItems(from: artifact.textContent)
            let data = TodoCardData(
                title: artifact.title,
                items: items
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "todo",
                section: .todo,
                record: record,
                cardView: items.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(TodoCard(data: data))
            )
        case .music:
            let data = MusicCardData(
                trackName: artifact.title,
                artistName: artifact.summary,
                albumName: artifact.metadata["albumName"] ?? artifact.textContent,
                albumArtworkURL: artifact.metadata["artworkURLString"].flatMap(URL.init(string:)),
                appleMusicURL: artifact.metadata["url"].flatMap(URL.init(string:))
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "music",
                section: .music,
                record: record,
                cardView: AnyView(MusicCard(data: data))
            )
        case .photo:
            let imagesData = [artifact.binaryPayload].compactMap { $0 }
            let coordinate = coordinate(from: artifact.metadata)
            let data = PhotoCardData(
                imagesData: imagesData,
                locationName: artifact.metadata["locationName"] ?? artifact.title,
                descriptionText: artifact.summary,
                locationCoordinate: coordinate,
                aiDescription: nonEmpty(artifact.textContent),
                trailingInfoText: imagesData.count > 1 ? "\(imagesData.count) photos" : ""
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "photo",
                section: .photo,
                record: record,
                cardView: imagesData.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(PhotoCard(data: data))
            )
        case .audio:
            let audioData = artifact.binaryPayload
            let data = AudioCardData(
                title: artifact.title.isEmpty ? "Voice" : artifact.title,
                audioData: audioData,
                transcriptPreview: artifact.textContent,
                durationText: audioDurationString(from: audioData),
                capturedAt: artifact.createdAt
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "audio",
                section: .audio,
                record: record,
                cardView: audioData == nil && artifact.textContent.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(AudioCard(data: data))
            )
        case .location:
            let coordinate = coordinate(from: artifact.metadata)
            let data = MapCardData(
                coordinate: coordinate,
                locationName: artifact.title,
                descriptionText: artifact.summary
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "map",
                section: .map,
                record: record,
                cardView: coordinate == nil && artifact.title.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(MapCard(data: data))
            )
        case .weather:
            if let condition = WeatherCondition(rawValue: artifact.metadata["condition"] ?? artifact.title) {
                let coordinate = coordinate(from: artifact.metadata)
                let temperature = Double(artifact.metadata["temperature"] ?? "") ?? 20
                let feelsLike = Double(artifact.metadata["feelsLike"] ?? "") ?? temperature
                let humidity = Int(artifact.metadata["humidity"] ?? "") ?? 60
                let high = Double(artifact.metadata["high"] ?? "") ?? temperature + 3
                let low = Double(artifact.metadata["low"] ?? "") ?? temperature - 3
                let data = WeatherCardData(
                    location: artifact.summary,
                    coordinate: coordinate,
                    temperature: temperature,
                    feelsLike: feelsLike,
                    condition: condition,
                    humidity: humidity,
                    high: high,
                    low: low,
                    observedAt: artifact.createdAt,
                    source: WeatherSnapshotSource(rawValue: artifact.metadata["source"] ?? "") ?? .manual
                )
                return renderedArtifactCard(
                    id: fallbackID,
                    spanKey: fallbackSpanKey,
                    presentationKey: "weather",
                    section: .weather,
                    record: record,
                    cardView: AnyView(WeatherCard(data: data))
                )
            }
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "weather",
                section: .weather,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .personMention:
            let person = PersonCardItem(
                id: artifact.id,
                name: artifact.title,
                relationship: artifact.metadata["relationship"] ?? "",
                mentionCount: 1
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "people",
                section: .people,
                record: record,
                cardView: AnyView(PeopleCard(data: PeopleCardData(people: [person])))
            )
        case .decisionNote:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "text",
                section: focusedSection == .people ? .people : .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .book:
            let data = BookCardData(
                title: nonEmpty(artifact.title) ?? "Book",
                author: artifact.metadata["author"] ?? artifact.summary,
                coverImageURL: artifact.metadata["coverImageURL"].flatMap(URL.init(string:)),
                progress: progressValue(from: artifact.metadata["progress"]),
                genre: nonEmpty(artifact.metadata["genre"] ?? ""),
                rating: Int(artifact.metadata["rating"] ?? "")
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "book",
                section: .text,
                record: record,
                cardView: data.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(BookCard(data: data))
            )
        case .film:
            let data = FilmCardData(
                title: nonEmpty(artifact.title) ?? "Film",
                year: artifact.metadata["year"] ?? "",
                posterImageURL: artifact.metadata["posterImageURL"].flatMap(URL.init(string:)),
                genre: nonEmpty(artifact.metadata["genre"] ?? ""),
                rating: Double(artifact.metadata["rating"] ?? ""),
                director: nonEmpty(artifact.metadata["director"] ?? ""),
                isWatched: boolValue(from: artifact.metadata["isWatched"])
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "film",
                section: .text,
                record: record,
                cardView: data.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(FilmCard(data: data))
            )
        case .game:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "game",
                section: .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .ticket:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "ticket",
                section: .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .healthMetric:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                presentationKey: "health",
                section: .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        }
    }

    private func renderedArtifactCard(
        id: String,
        spanKey: String,
        presentationKey: String,
        section: RecordSection,
        record: Record,
        cardView: AnyView
    ) -> RenderedArtifactCard {
        RenderedArtifactCard(
            id: id,
            spanKey: spanKey,
            presentationKey: presentationKey,
            record: record,
            focusedSection: section,
            cardView: cardView
        )
    }

    private func coordinate(from metadata: [String: String]) -> CLLocationCoordinate2D? {
        guard let latitude = Double(metadata["latitude"] ?? ""),
              let longitude = Double(metadata["longitude"] ?? "") else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func decodeTodoItems(from text: String) -> [TodoItem] {
        guard let data = text.data(using: .utf8),
              let items = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return items
    }

    private func nonEmpty(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func progressValue(from text: String?) -> Double? {
        guard let text = nonEmpty(text ?? "") else { return nil }
        guard let rawValue = Double(text) else { return nil }
        if rawValue > 1 {
            return max(0, min(rawValue / 100, 1))
        }
        return max(0, min(rawValue, 1))
    }

    private func boolValue(from text: String?) -> Bool {
        guard let normalized = nonEmpty(text ?? "")?.lowercased() else { return false }
        return normalized == "true" || normalized == "1" || normalized == "yes"
    }
}

struct RenderedArtifactCard {
    let id: String
    let spanKey: String
    let presentationKey: String
    let record: Record
    let focusedSection: RecordSection
    let cardView: AnyView
}

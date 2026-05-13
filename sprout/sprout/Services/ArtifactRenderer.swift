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
                cardType: "text",
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
                    cardType: "link",
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
                cardType: "link",
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
                cardType: "todo",
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
                cardType: "music",
                section: .music,
                record: record,
                cardView: AnyView(MusicCard(data: data))
            )
        case .photo:
            let matchingMedia = mediaCards(for: artifact, in: record).filter { $0.type == "photo" }
            let imagesData = matchingMedia.compactMap(\.imageData)
            let coordinate = coordinate(from: artifact.metadata) ?? mediaCoordinate(from: matchingMedia.first)
            let data = PhotoCardData(
                imagesData: imagesData,
                locationName: artifact.metadata["locationName"] ?? matchingMedia.first?.locationName ?? artifact.title,
                descriptionText: artifact.summary,
                locationCoordinate: coordinate,
                aiDescription: nonEmpty(artifact.textContent),
                trailingInfoText: imagesData.count > 1 ? "\(imagesData.count) photos" : ""
            )
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                cardType: "photo",
                section: .photo,
                record: record,
                cardView: imagesData.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(PhotoCard(data: data))
            )
        case .audio:
            let media = mediaCards(for: artifact, in: record).first(where: { $0.type == "audio" })
            let audioData = media?.audioData
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
                cardType: "audio",
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
                cardType: "map",
                section: .map,
                record: record,
                cardView: coordinate == nil && artifact.title.isEmpty
                    ? AnyView(ArtifactRowView(artifact: artifact, style: .card))
                    : AnyView(MapCard(data: data))
            )
        case .weather:
            if let condition = WeatherCondition(rawValue: artifact.metadata["condition"] ?? artifact.title) {
                let coordinate = coordinate(from: artifact.metadata)
                let temperature = Double(artifact.metadata["temperature"] ?? "") ?? record.temperature ?? 20
                let feelsLike = Double(artifact.metadata["feelsLike"] ?? "") ?? record.feelsLike ?? temperature
                let humidity = Int(artifact.metadata["humidity"] ?? "") ?? record.humidity ?? 60
                let high = Double(artifact.metadata["high"] ?? "") ?? record.weatherHigh ?? temperature + 3
                let low = Double(artifact.metadata["low"] ?? "") ?? record.weatherLow ?? temperature - 3
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
                    cardType: "weather",
                    section: .weather,
                    record: record,
                    cardView: AnyView(WeatherCard(data: data))
                )
            }
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                cardType: "weather",
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
                cardType: "people",
                section: .people,
                record: record,
                cardView: AnyView(PeopleCard(data: PeopleCardData(people: [person])))
            )
        case .decisionNote:
            return renderedArtifactCard(
                id: fallbackID,
                spanKey: fallbackSpanKey,
                cardType: "text",
                section: focusedSection == .people ? .people : .text,
                record: record,
                cardView: AnyView(ArtifactRowView(artifact: artifact, style: .card))
            )
        case .book, .film, .game, .ticket, .healthMetric:
            return nil
        }
    }

    private func renderedArtifactCard(
        id: String,
        spanKey: String,
        cardType: String,
        section: RecordSection,
        record: Record,
        cardView: AnyView
    ) -> RenderedArtifactCard {
        RenderedArtifactCard(
            id: id,
            spanKey: spanKey,
            cardType: cardType,
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

    private func mediaCards(for artifact: Artifact, in record: Record) -> [MediaCard] {
        (record.mediaCards ?? []).filter { $0.id == artifact.id }
    }

    private func mediaCoordinate(from media: MediaCard?) -> CLLocationCoordinate2D? {
        guard let media,
              let latitude = media.latitude,
              let longitude = media.longitude else {
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
}

struct RenderedArtifactCard {
    let id: String
    let spanKey: String
    let cardType: String
    let record: Record
    let focusedSection: RecordSection
    let cardView: AnyView
}

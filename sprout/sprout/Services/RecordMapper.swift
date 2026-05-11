import SwiftUI
import MapKit

// MARK: - RecordSection

/// Identifies a content section within a Record.
/// Used as the "entry angle" when navigating from a dashboard card to the detail view.
enum RecordSection: String, Hashable, CaseIterable {
    case text, emotion, weather, photo, music, link, activity, map, todo, audio, people, todayInHistory
}

// MARK: - DashboardCardInfo

/// A single card to be rendered on the home dashboard.
/// Multiple DashboardCardInfos can originate from the same Record.
struct DashboardCardInfo: Identifiable {
    let id: String
    /// Stable per-container key within the parent record, for example "photo" or "text".
    let spanKey: String
    /// Concrete card type for this dashboard container.
    let cardType: String
    /// The parent Record — same instance shared across all cards from that record.
    let record: Record
    /// Which section of the record this card represents (determines what's shown at top in detail view).
    let focusedSection: RecordSection
    /// Grid column span (2/4/6/8 based on card type limits).
    let columns: Int
    /// Grid height in units derived from record.cardUnits (1/2/4).
    let units: Int
    /// The rendered card view (navigation wrapping is added by CardWrapper in DailyView).
    let cardView: AnyView
}

// MARK: - RecordMapper

enum RecordMapper {

    /// Derives up to 4 dashboard cards from a single Record.
    /// Cards are ordered by visual importance (richest media first).
    /// Per-container size overrides are resolved by `spanKey`.
    /// Falls back to legacy record-level size when no per-container override exists.
    static func allCards(record: Record) -> [DashboardCardInfo] {
        var cards: [DashboardCardInfo] = []
        
        func resolvedSpan(for cardType: String, key: String) -> ContainerSpan {
            record.dashboardContainerSpan(for: key, cardType: cardType)
        }

        func cardInfo(
            suffix: String,
            type: String,
            section: RecordSection,
            cardView: AnyView
        ) -> DashboardCardInfo {
            let span = resolvedSpan(for: type, key: suffix)
            return DashboardCardInfo(
                id: "\(record.id.uuidString)-\(suffix)",
                spanKey: suffix,
                cardType: type,
                record: record,
                focusedSection: section,
                columns: span.widthColumns,
                units: span.heightUnits,
                cardView: cardView
            )
        }

        // ── Photos ────────────────────────────────────────────────────────────
        let photoMedia = (record.mediaCards ?? []).filter { $0.type == "photo" }
        if !photoMedia.isEmpty {
            let imagesData = photoMedia.compactMap { m -> Data? in
                m.imageData
            }
            let location = photoMedia.first?.locationName ?? record.location ?? ""
            let data = PhotoCardData(imagesData: imagesData, locationName: location, descriptionText: "")
            cards.append(cardInfo(
                suffix: "photo",
                type: "photo",
                section: .photo,
                cardView: AnyView(PhotoCard(data: imagesData.isEmpty ? nil : data))
            ))
        }

        // ── Music ─────────────────────────────────────────────────────────────
        if let m = (record.mediaCards ?? []).first(where: { $0.type == "music" }) {
            let data = MusicCardData(
                trackName: m.title ?? "",
                artistName: m.caption ?? "",
                albumName: m.albumName ?? "",
                albumArtworkURL: m.artworkURLString.flatMap(URL.init(string:)),
                appleMusicURL: m.url.flatMap { URL(string: $0) }
            )
            cards.append(cardInfo(
                suffix: "music",
                type: "music",
                section: .music,
                cardView: AnyView(MusicCard(data: data))
            ))
        }

        // ── Audio ─────────────────────────────────────────────────────────────
        if let m = (record.mediaCards ?? []).first(where: { $0.type == "audio" }) {
            cards.append(cardInfo(
                suffix: "audio",
                type: "audio",
                section: .audio,
                cardView: AnyView(
                    AudioCard(
                        data: AudioCardData(
                            title: m.title ?? "",
                            audioData: m.audioData,
                            transcriptPreview: m.caption ?? "",
                            durationText: audioDurationString(from: m.audioData),
                            capturedAt: m.capturedAt ?? record.createdAt
                        )
                    )
                )
            ))
        }

        // ── Links ─────────────────────────────────────────────────────────────
        let linkMedia = (record.mediaCards ?? []).filter { $0.type == "link" }
        if !linkMedia.isEmpty {
            let items = linkMedia.compactMap { m -> LinkItem? in
                guard let urlStr = m.url, let url = URL(string: urlStr) else { return nil }
                return LinkItem(url: url, title: m.title ?? urlStr, description: m.caption ?? "")
            }
            if !items.isEmpty {
                cards.append(cardInfo(
                    suffix: "link",
                    type: "link",
                    section: .link,
                    cardView: AnyView(LinkCard(data: LinkCardData(links: items)))
                ))
            }
        }

        // ── Map ───────────────────────────────────────────────────────────────
        if let lat = record.latitude, let lng = record.longitude {
            let data = MapCardData(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                locationName: record.location ?? ""
            )
            cards.append(cardInfo(
                suffix: "map",
                type: "map",
                section: .map,
                cardView: AnyView(MapCard(data: data))
            ))
        }

        // ── Activity ──────────────────────────────────────────────────────────
        if let act = record.activity, let value = act.value, value > 0 {
            let actType = ActivityType(rawValue: act.type) ?? .steps
            let data = ActivityCardData(
                type: actType,
                value: value,
                goal: act.goal ?? 0,
                durationMinutes: act.durationMinutes ?? 0
            )
            cards.append(cardInfo(
                suffix: "activity",
                type: "activity",
                section: .activity,
                cardView: AnyView(ActivityCard(data: data))
            ))
        }

        // ── Emotion ───────────────────────────────────────────────────────────
        if let moodStr = record.mood, let mood = MoodType(rawValue: moodStr) {
            let data = EmotionCardData(mood: mood, note: "", intensity: record.intensity ?? 3)
            cards.append(cardInfo(
                suffix: "emotion",
                type: "emotion",
                section: .emotion,
                cardView: AnyView(EmotionCard(data: data))
            ))
        }

        // ── Weather ───────────────────────────────────────────────────────────
        if let weatherStr = record.weather, let condition = WeatherCondition(rawValue: weatherStr) {
            let temp = record.temperature ?? 20
            let data = WeatherCardData(
                location: record.location ?? "",
                coordinate: {
                    if let latitude = record.latitude, let longitude = record.longitude {
                        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    }
                    return nil
                }(),
                temperature: temp,
                feelsLike: record.feelsLike ?? (temp - 2),
                condition: condition,
                humidity: record.humidity ?? 60,
                high: record.weatherHigh ?? (temp + 3),
                low: record.weatherLow ?? (temp - 3),
                observedAt: record.weatherObservedAt,
                source: WeatherSnapshotSource(rawValue: record.weatherSource ?? "") ?? .manual
            )
            cards.append(cardInfo(
                suffix: "weather",
                type: "weather",
                section: .weather,
                cardView: AnyView(WeatherCard(data: data))
            ))
        }

        // ── Todo ──────────────────────────────────────────────────────────────
        if let todoMedia = (record.mediaCards ?? []).first(where: { $0.type == "todo" }) {
            var todoData = TodoCardData(title: todoMedia.title ?? "")
            if let json = todoMedia.caption,
               let raw = json.data(using: .utf8),
               let items = try? JSONDecoder().decode([TodoItem].self, from: raw) {
                todoData.items = items
            }
            if !todoData.isEmpty {
                cards.append(cardInfo(
                    suffix: "todo",
                    type: "todo",
                    section: .todo,
                    cardView: AnyView(TodoCard(data: todoData))
                ))
            }
        }

        // ── People ────────────────────────────────────────────────────────────
        let mentionedPeople = record.mentionedPeople ?? []
        if !mentionedPeople.isEmpty {
            cards.append(cardInfo(
                suffix: "people",
                type: "people",
                section: .people,
                cardView: AnyView(
                    PeopleCard(
                        data: PeopleCardData(
                            people: mentionedPeople.map { PersonCardItem(person: $0) }
                        )
                    )
                )
            ))
        }

        // ── Text / Quote ──────────────────────────────────────────────────────
        if !record.body.isEmpty {
            let data = QuoteCardData(
                quote: record.body,
                author: record.tagValue(for: "author"),
                source: record.tagValue(for: "source")
            )
            cards.append(cardInfo(
                suffix: "text",
                type: "text",
                section: .text,
                cardView: AnyView(QuoteCard(data: data))
            ))
        }

        // Cap at 4 cards per record
        return Array(cards.prefix(4))
    }
}

// MARK: - Record helpers

extension Record {
    /// Extracts a value stored in tags with the format "key:value".
    func tagValue(for key: String) -> String {
        tags
            .first { $0.hasPrefix("\(key):") }
            .map { String($0.dropFirst(key.count + 1)) }
            ?? ""
    }
}

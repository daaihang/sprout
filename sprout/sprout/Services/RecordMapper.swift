import SwiftUI
import UIKit
import MapKit

// MARK: - RecordSection

/// Identifies a content section within a Record.
/// Used as the "entry angle" when navigating from a dashboard card to the detail view.
enum RecordSection: String, Hashable, CaseIterable {
    case text, emotion, weather, photo, music, link, activity, map, todo
}

// MARK: - DashboardCardInfo

/// A single card to be rendered on the home dashboard.
/// Multiple DashboardCardInfos can originate from the same Record.
struct DashboardCardInfo: Identifiable {
    let id = UUID()
    /// The parent Record — same instance shared across all cards from that record.
    let record: Record
    /// Which section of the record this card represents (determines what's shown at top in detail view).
    let focusedSection: RecordSection
    /// Grid column span (always 4 for now — full-width cards).
    let columns: Int
    /// Grid height in units (1 = thin, 2 = medium, 4 = tall).
    let units: Int
    /// The rendered card view (no navigation wrapping — ContentView adds that).
    let cardView: AnyView
}

// MARK: - RecordMapper

enum RecordMapper {

    /// Derives up to 4 dashboard cards from a single Record.
    /// Cards are ordered by visual importance (richest media first).
    static func allCards(record: Record) -> [DashboardCardInfo] {
        var cards: [DashboardCardInfo] = []

        // ── Photos ────────────────────────────────────────────────────────────
        let photoMedia = (record.mediaCards ?? []).filter { $0.type == "photo" }
        if !photoMedia.isEmpty {
            let images = photoMedia.compactMap { m -> UIImage? in
                guard let d = m.imageData else { return nil }
                return UIImage(data: d)
            }
            if !images.isEmpty || !photoMedia.isEmpty {
                // Show placeholder card even without decoded images (they may be loading)
                let location = photoMedia.first?.locationName ?? record.location ?? ""
                let data = PhotoCardData(images: images, locationName: location, descriptionText: "")
                let units = cards.isEmpty ? 4 : 2
                cards.append(DashboardCardInfo(
                    record: record, focusedSection: .photo,
                    columns: 4, units: units,
                    cardView: AnyView(PhotoCard(size: CardSize(columns: 4, units: units), data: data.images.isEmpty ? nil : data))
                ))
            }
        }

        // ── Music ─────────────────────────────────────────────────────────────
        if let m = (record.mediaCards ?? []).first(where: { $0.type == "music" }) {
            let artwork: UIImage? = m.thumbnailData.flatMap { UIImage(data: $0) }
            let data = MusicCardData(
                trackName: m.title ?? "",
                artistName: m.caption ?? "",
                albumName: "",
                albumArtwork: artwork,
                appleMusicURL: m.url.flatMap { URL(string: $0) }
            )
            let units = cards.isEmpty ? 2 : 1
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .music,
                columns: 4, units: units,
                cardView: AnyView(MusicCard(size: CardSize(columns: 4, units: units), data: data))
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
                let data = LinkCardData(links: items)
                let units = cards.isEmpty ? 2 : 2
                cards.append(DashboardCardInfo(
                    record: record, focusedSection: .link,
                    columns: 4, units: units,
                    cardView: AnyView(LinkCard(size: CardSize(columns: 4, units: units), data: data))
                ))
            }
        }

        // ── Map ───────────────────────────────────────────────────────────────
        if let lat = record.latitude, let lng = record.longitude {
            let data = MapCardData(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                locationName: record.location ?? ""
            )
            let units = cards.isEmpty ? 4 : 2
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .map,
                columns: 4, units: units,
                cardView: AnyView(MapCard(size: CardSize(columns: 4, units: units), data: data))
            ))
        }

        // ── Activity ──────────────────────────────────────────────────────────
        if let act = record.activity, let value = act.value, value > 0 {
            let type = ActivityType(rawValue: act.type) ?? .steps
            let data = ActivityCardData(
                type: type,
                value: value,
                goal: act.goal ?? 0,
                durationMinutes: act.durationMinutes ?? 0
            )
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .activity,
                columns: 4, units: 2,
                cardView: AnyView(ActivityCard(size: .w4h2, data: data))
            ))
        }

        // ── Emotion ───────────────────────────────────────────────────────────
        if let moodStr = record.mood, let mood = MoodType(rawValue: moodStr) {
            let data = EmotionCardData(mood: mood, note: "", intensity: record.intensity ?? 3)
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .emotion,
                columns: 4, units: 1,
                cardView: AnyView(EmotionCard(size: .w4h1, data: data))
            ))
        }

        // ── Weather ───────────────────────────────────────────────────────────
        if let weatherStr = record.weather, let condition = WeatherCondition(rawValue: weatherStr) {
            let temp = record.temperature ?? 20
            let data = WeatherCardData(
                location: record.location ?? "",
                temperature: temp,
                feelsLike: temp - 2,
                condition: condition,
                humidity: 60,
                high: temp + 3,
                low: temp - 3
            )
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .weather,
                columns: 4, units: 1,
                cardView: AnyView(WeatherCard(size: .w4h1, data: data))
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
                let units = cards.isEmpty ? 4 : 2
                cards.append(DashboardCardInfo(
                    record: record, focusedSection: .todo,
                    columns: 4, units: units,
                    cardView: AnyView(TodoCard(size: CardSize(columns: 4, units: units), data: todoData))
                ))
            }
        }

        // ── Text / Quote ──────────────────────────────────────────────────────
        if !record.body.isEmpty {
            let author = record.tagValue(for: "author")
            let source = record.tagValue(for: "source")
            let data = QuoteCardData(quote: record.body, author: author, source: source)
            let units = cards.isEmpty ? 2 : 1
            cards.append(DashboardCardInfo(
                record: record, focusedSection: .text,
                columns: 4, units: units,
                cardView: AnyView(QuoteCard(size: CardSize(columns: 4, units: units), data: data))
            ))
        }

        // Cap at 4 cards per record to avoid one record overwhelming the dashboard
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

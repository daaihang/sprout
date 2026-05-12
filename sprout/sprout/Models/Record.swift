import Foundation
import SwiftData

@Model
final class Record {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var body: String = ""
    var mood: String? = nil
    var weather: String? = nil
    var temperature: Double? = nil
    var location: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var isPinned: Bool = false
    var tags: [String] = []
    var completedAt: Date? = nil
    var intensity: Int? = nil
    var genre: String? = nil
    var rating: Int? = nil
    var isWatched: Bool = false
    var director: String? = nil
    var progress: Double? = nil
    var appleMusicURL: String? = nil
    /// Primary card type for dashboard display.
    /// Values: "text" | "quote" | "emotion" | "weather" | "activity" | "todo" | "photo" | "music" | "link" | "map" | "audio" | "people" | "today_in_history"
    var cardType: String = "text"
    /// Weather extended fields (replaces hardcoded defaults in RecordMapper)
    var feelsLike: Double? = nil
    var humidity: Int? = nil
    var weatherHigh: Double? = nil
    var weatherLow: Double? = nil
    /// Timestamp for the captured weather snapshot.
    var weatherObservedAt: Date? = nil
    /// Source of the weather snapshot, for example "current_location_auto" or "manual".
    var weatherSource: String? = nil
    /// User-preferred display height in grid units (1 / 2 / 4). Default 4 = full-size card.
    var cardUnits: Int = 4
    /// User-preferred display width in grid columns (2 / 4 / 6 / 8). Default 4 = full-width card.
    var cardWidthColumns: Int = 4
    /// Per-dashboard-container span overrides keyed by card suffix, stored as JSON.
    var dashboardCardSpanOverridesData: Data? = nil
    /// Dashboard ordering rank. Lower values appear earlier.
    var dashboardOrder: Double = 0

    var containerSpan: ContainerSpan {
        ContainerSpan(widthColumns: cardWidthColumns, heightUnits: cardUnits)
    }

    @Relationship(deleteRule: .cascade) var mediaCards: [MediaCard]? = nil
    @Relationship(deleteRule: .nullify) var mentionedPeople: [Person]? = nil
    @Relationship(deleteRule: .nullify) var linkedDecisions: [Decision]? = nil
    @Relationship(deleteRule: .nullify) var activity: Activity? = nil
    @Relationship(deleteRule: .nullify) var dailyQuestion: DailyQuestion? = nil

    init() {}
}

private struct StoredDashboardCardSpan: Codable {
    let widthColumns: Int
    let heightUnits: Int
}

extension Record {
    private enum DashboardCardSpanOverridesCache {
        static var storage: [ObjectIdentifier: CacheEntry] = [:]

        struct CacheEntry {
            let data: Data?
            let overrides: [String: StoredDashboardCardSpan]
        }
    }

    private var dashboardCardSpanOverrides: [String: StoredDashboardCardSpan] {
        get {
            let identifier = ObjectIdentifier(self)
            let cached = DashboardCardSpanOverridesCache.storage[identifier]
            if cached?.data == dashboardCardSpanOverridesData {
                return cached?.overrides ?? [:]
            }

            let overrides: [String: StoredDashboardCardSpan]
            if let dashboardCardSpanOverridesData {
                overrides = (try? JSONDecoder().decode(
                    [String: StoredDashboardCardSpan].self,
                    from: dashboardCardSpanOverridesData
                )) ?? [:]
            } else {
                overrides = [:]
            }

            DashboardCardSpanOverridesCache.storage[identifier] = DashboardCardSpanOverridesCache.CacheEntry(
                data: dashboardCardSpanOverridesData,
                overrides: overrides
            )
            return overrides
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            dashboardCardSpanOverridesData = encoded
            DashboardCardSpanOverridesCache.storage[ObjectIdentifier(self)] = DashboardCardSpanOverridesCache.CacheEntry(
                data: encoded,
                overrides: newValue
            )
        }
    }

    func dashboardContainerSpan(for key: String, cardType: String) -> ContainerSpan {
        if let stored = dashboardCardSpanOverrides[key] {
            return sizeLimits(for: cardType).clamped(
                span: ContainerSpan(widthColumns: stored.widthColumns, heightUnits: stored.heightUnits)
            )
        }

        return sizeLimits(for: cardType).clamped(span: containerSpan)
    }

    func hasDashboardContainerSpanOverride(for key: String) -> Bool {
        dashboardCardSpanOverrides[key] != nil
    }

    func setDashboardContainerSpan(_ span: ContainerSpan, for key: String) {
        var overrides = dashboardCardSpanOverrides
        overrides[key] = StoredDashboardCardSpan(
            widthColumns: span.widthColumns,
            heightUnits: span.heightUnits
        )
        dashboardCardSpanOverrides = overrides
    }
}

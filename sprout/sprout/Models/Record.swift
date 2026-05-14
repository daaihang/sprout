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
    /// Weather extended fields captured at record time.
    var feelsLike: Double? = nil
    var humidity: Int? = nil
    var weatherHigh: Double? = nil
    var weatherLow: Double? = nil
    /// Timestamp for the captured weather snapshot.
    var weatherObservedAt: Date? = nil
    /// Source of the weather snapshot, for example "current_location_auto" or "manual".
    var weatherSource: String? = nil
    /// Dashboard ordering rank. Lower values appear earlier.
    var dashboardOrder: Double = 0

    @Relationship(deleteRule: .nullify) var mentionedPeople: [Person]? = nil
    @Relationship(deleteRule: .nullify) var linkedDecisions: [Decision]? = nil
    @Relationship(deleteRule: .nullify) var activity: Activity? = nil
    @Relationship(deleteRule: .nullify) var dailyQuestion: DailyQuestion? = nil

    init() {}
}

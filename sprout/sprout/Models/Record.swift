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
    /// Values: "text" | "quote" | "emotion" | "weather" | "activity" | "todo" | "photo" | "music" | "link" | "map"
    var cardType: String = "text"

    @Relationship(deleteRule: .cascade) var mediaCards: [MediaCard]? = nil
    @Relationship(deleteRule: .nullify) var mentionedPeople: [Person]? = nil
    @Relationship(deleteRule: .nullify) var linkedDecisions: [Decision]? = nil
    @Relationship(deleteRule: .nullify) var activity: Activity? = nil
    @Relationship(deleteRule: .nullify) var dailyQuestion: DailyQuestion? = nil

    init() {}
}

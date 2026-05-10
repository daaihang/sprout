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

    @Relationship(deleteRule: .cascade) var mediaCards: [MediaCard]? = nil
    @Relationship(deleteRule: .nullify) var mentionedPeople: [Person]? = nil
    @Relationship(deleteRule: .nullify) var linkedDecisions: [Decision]? = nil
    @Relationship(deleteRule: .nullify) var activity: Activity? = nil
    @Relationship(deleteRule: .nullify) var dailyQuestion: DailyQuestion? = nil

    init() {}
}

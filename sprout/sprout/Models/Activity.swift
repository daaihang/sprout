import Foundation
import SwiftData

@Model
final class Activity {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var type: String = "custom"
    var name: String = ""
    var value: Double? = nil
    var unit: String? = nil
    var durationMinutes: Int? = nil
    var note: String? = nil
    var sourceIdentifier: String? = nil
    var completedAt: Date? = nil
    var goal: Double? = nil
    var isCompleted: Bool = false
    var updatedAt: Date = Date()

    init() {}
}

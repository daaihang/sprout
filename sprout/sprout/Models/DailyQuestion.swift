import Foundation
import SwiftData

@Model
final class DailyQuestion {
    var id: UUID = UUID()
    var date: Date = Date()
    var questionText: String = ""
    var answerText: String? = nil
    var answeredAt: Date? = nil
    var isAnswered: Bool = false

    @Relationship(inverse: \Record.dailyQuestion) var record: Record? = nil

    init() {}
}

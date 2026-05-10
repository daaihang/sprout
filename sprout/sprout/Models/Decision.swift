import Foundation
import SwiftData

@Model
final class Decision {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    var context: String? = nil
    var outcome: String? = nil
    var status: String = "pending"
    var decidedAt: Date? = nil
    var reviewAt: Date? = nil

    @Relationship(inverse: \Record.linkedDecisions) var records: [Record]? = nil

    init() {}
}

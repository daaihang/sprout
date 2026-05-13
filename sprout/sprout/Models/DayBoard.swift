import Foundation
import SwiftData

@Model
final class DayBoard {
    var id: UUID = UUID()
    var boardKey: String = ""
    var kind: String = DayBoardKind.homeDay.rawValue
    var boardDate: Date = Date()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        boardKey: String,
        kind: DayBoardKind = .homeDay,
        boardDate: Date,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.boardKey = boardKey
        self.kind = kind.rawValue
        self.boardDate = boardDate
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum DayBoardKind: String, Codable, CaseIterable, Sendable {
    case homeDay
}

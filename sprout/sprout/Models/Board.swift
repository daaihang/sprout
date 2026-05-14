import Foundation
import SwiftData

@Model
final class Board {
    var id: UUID = UUID()
    var boardKey: String = ""
    var kind: String = BoardKind.homeDay.rawValue
    var boardDate: Date = Date()
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        boardKey: String,
        kind: BoardKind = .homeDay,
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

enum BoardKind: String, Codable, CaseIterable, Sendable {
    case homeDay
}

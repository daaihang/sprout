import Foundation

struct Composition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var boardID: UUID
    var title: String
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        boardID: UUID,
        title: String,
        sortOrder: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

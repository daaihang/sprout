import Foundation
import SwiftData

@Model
final class Composition {
    var id: UUID = UUID()
    var boardID: UUID = UUID()
    var compositionKey: String = ""
    var kind: String = CompositionKind.primary.rawValue
    var title: String = ""
    var layoutStyle: String = "dashboard_grid"
    var sortOrder: Double = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        boardID: UUID,
        compositionKey: String,
        kind: CompositionKind = .primary,
        title: String,
        layoutStyle: String = "dashboard_grid",
        sortOrder: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.boardID = boardID
        self.compositionKey = compositionKey
        self.kind = kind.rawValue
        self.title = title
        self.layoutStyle = layoutStyle
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum CompositionKind: String, Codable, CaseIterable, Sendable {
    case primary
}

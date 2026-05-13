import Foundation

enum BoardKind: String, Codable, CaseIterable, Sendable {
    case homeDay
    case person
    case arc
    case review
}

struct Board: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: BoardKind
    var title: String
    var subtitle: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: BoardKind,
        title: String,
        subtitle: String,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.createdAt = createdAt
    }
}

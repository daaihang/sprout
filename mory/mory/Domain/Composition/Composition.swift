import Foundation

enum BoardKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case homeDay
    case people
    case arc
    case search
    case reflections

    var id: String { rawValue }
}

enum CompositionTargetType: String, Codable, CaseIterable, Identifiable, Sendable {
    case artifact
    case record
    case entity
    case arc
    case reflection
    case system

    var id: String { rawValue }
}

enum HomeBoardCardKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case memory
    case arc
    case reflection
    case clarificationQuestion
    case systemPrompt
    case contextCluster
    case pendingAction

    var id: String { rawValue }
}

struct HomeBoardItemPreference: Identifiable, Codable, Hashable, Sendable {
    static let schemaVersion = 1

    let id: UUID
    var schemaVersion: Int
    var syncKey: String
    var boardKey: String
    var cardKey: String
    var cardKind: HomeBoardCardKind
    var targetType: CompositionTargetType
    var targetID: UUID
    var isPinned: Bool
    var isHidden: Bool
    var dismissedAt: Date?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = HomeBoardItemPreference.schemaVersion,
        syncKey: String,
        boardKey: String = "home-board",
        cardKey: String,
        cardKind: HomeBoardCardKind,
        targetType: CompositionTargetType,
        targetID: UUID,
        isPinned: Bool = false,
        isHidden: Bool = false,
        dismissedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.syncKey = syncKey
        self.boardKey = boardKey
        self.cardKey = cardKey
        self.cardKind = cardKind
        self.targetType = targetType
        self.targetID = targetID
        self.isPinned = isPinned
        self.isHidden = isHidden
        self.dismissedAt = dismissedAt
        self.updatedAt = updatedAt
    }
}

enum HomeBoardPreferenceAction: Sendable {
    case pin(Bool)
    case hide
    case dismiss
}

struct Board: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var boardKey: String
    var kind: BoardKind
    var title: String
    var subtitle: String
    var boardDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        boardKey: String,
        kind: BoardKind,
        title: String,
        subtitle: String,
        boardDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardKey = boardKey
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.boardDate = boardDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Composition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var boardID: UUID
    var compositionKey: String
    var title: String
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        boardID: UUID,
        compositionKey: String,
        title: String,
        sortOrder: Double,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.compositionKey = compositionKey
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CompositionItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var boardID: UUID
    var boardKey: String
    var compositionID: UUID
    var compositionKey: String
    var itemKey: String
    var targetType: CompositionTargetType
    var targetID: UUID
    var widthColumns: Int
    var heightUnits: Int
    var zIndex: Int
    var rotationDegrees: Double
    var scale: Double
    var isHidden: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        boardID: UUID,
        boardKey: String,
        compositionID: UUID,
        compositionKey: String,
        itemKey: String,
        targetType: CompositionTargetType,
        targetID: UUID,
        widthColumns: Int,
        heightUnits: Int,
        zIndex: Int,
        rotationDegrees: Double = 0,
        scale: Double = 1,
        isHidden: Bool = false,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.boardKey = boardKey
        self.compositionID = compositionID
        self.compositionKey = compositionKey
        self.itemKey = itemKey
        self.targetType = targetType
        self.targetID = targetID
        self.widthColumns = widthColumns
        self.heightUnits = heightUnits
        self.zIndex = zIndex
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        self.isHidden = isHidden
        self.updatedAt = updatedAt
    }
}

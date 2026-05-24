import Foundation
import SwiftData

@Model
final class HomeBoardSignalStore {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var targetTypeRawValue: String
    var targetID: UUID
    var sourceRecordIDs: [UUID]
    var title: String
    var subtitle: String
    var priority: Double
    var reason: String
    var suggestedWidthColumns: Int
    var suggestedHeightUnits: Int
    var createdAt: Date
    var expiresAt: Date?

    init(
        id: UUID,
        kindRawValue: String,
        targetTypeRawValue: String,
        targetID: UUID,
        sourceRecordIDs: [UUID] = [],
        title: String,
        subtitle: String,
        priority: Double,
        reason: String,
        suggestedWidthColumns: Int,
        suggestedHeightUnits: Int,
        createdAt: Date,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kindRawValue
        self.targetTypeRawValue = targetTypeRawValue
        self.targetID = targetID
        self.sourceRecordIDs = sourceRecordIDs
        self.title = title
        self.subtitle = subtitle
        self.priority = priority
        self.reason = reason
        self.suggestedWidthColumns = suggestedWidthColumns
        self.suggestedHeightUnits = suggestedHeightUnits
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

@Model
final class BoardStore {
    @Attribute(.unique) var id: UUID
    var boardKey: String
    var kindRawValue: String
    var title: String
    var subtitle: String
    var boardDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
        boardKey: String,
        kindRawValue: String,
        title: String,
        subtitle: String,
        boardDate: Date? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.boardKey = boardKey
        self.kindRawValue = kindRawValue
        self.title = title
        self.subtitle = subtitle
        self.boardDate = boardDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CompositionStore {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var compositionKey: String
    var title: String
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID,
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

@Model
final class CompositionItemStore {
    @Attribute(.unique) var id: UUID
    var boardID: UUID
    var boardKey: String
    var compositionID: UUID
    var compositionKey: String
    var itemKey: String
    var targetTypeRawValue: String
    var targetID: UUID
    var widthColumns: Int
    var heightUnits: Int
    var zIndex: Int
    var rotationDegrees: Double
    var scale: Double
    var isHidden: Bool
    var updatedAt: Date

    init(
        id: UUID,
        boardID: UUID,
        boardKey: String,
        compositionID: UUID,
        compositionKey: String,
        itemKey: String,
        targetTypeRawValue: String,
        targetID: UUID,
        widthColumns: Int,
        heightUnits: Int,
        zIndex: Int,
        rotationDegrees: Double,
        scale: Double,
        isHidden: Bool,
        updatedAt: Date
    ) {
        self.id = id
        self.boardID = boardID
        self.boardKey = boardKey
        self.compositionID = compositionID
        self.compositionKey = compositionKey
        self.itemKey = itemKey
        self.targetTypeRawValue = targetTypeRawValue
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

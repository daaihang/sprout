import Foundation

@MainActor
extension HomeBoardSignalStore {
    convenience init(domainModel: HomeBoardSignal) {
        self.init(
            id: domainModel.id,
            kindRawValue: domainModel.kind.rawValue,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            sourceRecordIDs: domainModel.sourceRecordIDs,
            title: domainModel.title,
            subtitle: domainModel.subtitle,
            priority: domainModel.priority,
            reason: domainModel.reason,
            suggestedWidthColumns: domainModel.suggestedWidthColumns,
            suggestedHeightUnits: domainModel.suggestedHeightUnits,
            createdAt: domainModel.createdAt,
            expiresAt: domainModel.expiresAt
        )
    }

    var domainModel: HomeBoardSignal {
        HomeBoardSignal(
            id: id,
            kind: HomeBoardSignalKind(rawValue: kindRawValue) ?? .clarificationQuestion,
            targetType: ClarificationTargetType(rawValue: targetTypeRawValue) ?? .record,
            targetID: targetID,
            sourceRecordIDs: sourceRecordIDs,
            title: title,
            subtitle: subtitle,
            priority: priority,
            reason: reason,
            suggestedWidthColumns: suggestedWidthColumns,
            suggestedHeightUnits: suggestedHeightUnits,
            createdAt: createdAt,
            expiresAt: expiresAt
        )
    }

    func apply(domainModel: HomeBoardSignal) {
        id = domainModel.id
        kindRawValue = domainModel.kind.rawValue
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        sourceRecordIDs = domainModel.sourceRecordIDs
        title = domainModel.title
        subtitle = domainModel.subtitle
        priority = domainModel.priority
        reason = domainModel.reason
        suggestedWidthColumns = domainModel.suggestedWidthColumns
        suggestedHeightUnits = domainModel.suggestedHeightUnits
        createdAt = domainModel.createdAt
        expiresAt = domainModel.expiresAt
    }
}

@MainActor
extension BoardStore {
    convenience init(domainModel: Board) {
        self.init(
            id: domainModel.id,
            boardKey: domainModel.boardKey,
            kindRawValue: domainModel.kind.rawValue,
            title: domainModel.title,
            subtitle: domainModel.subtitle,
            boardDate: domainModel.boardDate,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Board {
        Board(
            id: id,
            boardKey: boardKey,
            kind: BoardKind(rawValue: kindRawValue) ?? .homeDay,
            title: title,
            subtitle: subtitle,
            boardDate: boardDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Board) {
        id = domainModel.id
        boardKey = domainModel.boardKey
        kindRawValue = domainModel.kind.rawValue
        title = domainModel.title
        subtitle = domainModel.subtitle
        boardDate = domainModel.boardDate
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionStore {
    convenience init(domainModel: Composition) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            compositionKey: domainModel.compositionKey,
            title: domainModel.title,
            sortOrder: domainModel.sortOrder,
            createdAt: domainModel.createdAt,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: Composition {
        Composition(
            id: id,
            boardID: boardID,
            compositionKey: compositionKey,
            title: title,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: Composition) {
        id = domainModel.id
        boardID = domainModel.boardID
        compositionKey = domainModel.compositionKey
        title = domainModel.title
        sortOrder = domainModel.sortOrder
        createdAt = domainModel.createdAt
        updatedAt = domainModel.updatedAt
    }
}

@MainActor
extension CompositionItemStore {
    convenience init(domainModel: CompositionItem) {
        self.init(
            id: domainModel.id,
            boardID: domainModel.boardID,
            boardKey: domainModel.boardKey,
            compositionID: domainModel.compositionID,
            compositionKey: domainModel.compositionKey,
            itemKey: domainModel.itemKey,
            targetTypeRawValue: domainModel.targetType.rawValue,
            targetID: domainModel.targetID,
            widthColumns: domainModel.widthColumns,
            heightUnits: domainModel.heightUnits,
            zIndex: domainModel.zIndex,
            rotationDegrees: domainModel.rotationDegrees,
            scale: domainModel.scale,
            isHidden: domainModel.isHidden,
            updatedAt: domainModel.updatedAt
        )
    }

    var domainModel: CompositionItem {
        CompositionItem(
            id: id,
            boardID: boardID,
            boardKey: boardKey,
            compositionID: compositionID,
            compositionKey: compositionKey,
            itemKey: itemKey,
            targetType: CompositionTargetType(rawValue: targetTypeRawValue) ?? .artifact,
            targetID: targetID,
            widthColumns: widthColumns,
            heightUnits: heightUnits,
            zIndex: zIndex,
            rotationDegrees: rotationDegrees,
            scale: scale,
            isHidden: isHidden,
            updatedAt: updatedAt
        )
    }

    func apply(domainModel: CompositionItem) {
        id = domainModel.id
        boardID = domainModel.boardID
        boardKey = domainModel.boardKey
        compositionID = domainModel.compositionID
        compositionKey = domainModel.compositionKey
        itemKey = domainModel.itemKey
        targetTypeRawValue = domainModel.targetType.rawValue
        targetID = domainModel.targetID
        widthColumns = domainModel.widthColumns
        heightUnits = domainModel.heightUnits
        zIndex = domainModel.zIndex
        rotationDegrees = domainModel.rotationDegrees
        scale = domainModel.scale
        isHidden = domainModel.isHidden
        updatedAt = domainModel.updatedAt
    }
}


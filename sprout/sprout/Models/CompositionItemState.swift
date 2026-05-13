import Foundation
import SwiftData

@Model
final class CompositionItemState {
    var id: UUID = UUID()
    var boardKey: String = ""
    var itemKey: String = ""
    var targetType: String = ""
    var targetID: UUID = UUID()
    var widthColumns: Int = 4
    var heightUnits: Int = 4
    var rotationDegrees: Double = 0
    var scale: Double = 1
    var updatedAt: Date = Date()

    init(
        boardKey: String,
        itemKey: String,
        targetType: String,
        targetID: UUID,
        widthColumns: Int,
        heightUnits: Int,
        rotationDegrees: Double = 0,
        scale: Double = 1,
        updatedAt: Date = Date()
    ) {
        self.boardKey = boardKey
        self.itemKey = itemKey
        self.targetType = targetType
        self.targetID = targetID
        self.widthColumns = widthColumns
        self.heightUnits = heightUnits
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        self.updatedAt = updatedAt
    }
}

extension CompositionItemState {
    var span: ContainerSpan {
        ContainerSpan(widthColumns: widthColumns, heightUnits: heightUnits)
    }

    func setSpan(_ span: ContainerSpan) {
        widthColumns = span.widthColumns
        heightUnits = span.heightUnits
        updatedAt = Date()
    }

    func setVisualState(rotationDegrees: Double, scale: Double) {
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        updatedAt = Date()
    }
}

import Foundation

enum CompositionTargetType: String, Codable, CaseIterable, Sendable {
    case artifact
    case record
    case reflection
    case arc
}

struct CompositionPositionHint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}

struct CompositionItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var compositionID: UUID
    var targetType: CompositionTargetType
    var targetID: UUID
    var widthUnits: Int
    var heightUnits: Int
    var zIndex: Int
    var rotation: Double
    var scale: Double
    var positionHint: CompositionPositionHint

    init(
        id: UUID = UUID(),
        compositionID: UUID,
        targetType: CompositionTargetType,
        targetID: UUID,
        widthUnits: Int,
        heightUnits: Int,
        zIndex: Int,
        rotation: Double,
        scale: Double,
        positionHint: CompositionPositionHint
    ) {
        self.id = id
        self.compositionID = compositionID
        self.targetType = targetType
        self.targetID = targetID
        self.widthUnits = widthUnits
        self.heightUnits = heightUnits
        self.zIndex = zIndex
        self.rotation = rotation
        self.scale = scale
        self.positionHint = positionHint
    }
}

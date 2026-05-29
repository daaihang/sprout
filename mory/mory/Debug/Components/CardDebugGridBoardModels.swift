import SwiftUI

enum CardDebugGridBoardPlacementMode: String, CaseIterable, Identifiable {
    case storedPlacement = "Stored Interactive"
    case nilPlacementFallback = "Nil Legacy"
    case firstFitEffectivePlacement = "First Fit"

    var id: String { rawValue }
}

struct CardDebugGridBoardLabItem: Identifiable, Hashable {
    let id: UUID
    var title: String
    var size: MemoryCardSizeToken
    var recipe: MemoryCardVisualRecipe
    var placement: MemoryCardGridPlacement?
    var isPinned = false
    var isUserAdjusted = false
}

struct CardDebugGridBoardLabSlot: Identifiable, Hashable {
    let id: UUID
    let item: CardDebugGridBoardLabItem
    let layout: MemoryCardLayoutToken
    let frame: CGRect

    var gridBox: MemoryCardGridBox {
        MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
    }

    var cells: [CardDebugGridCell] {
        guard let placement = layout.gridPlacement else { return [] }
        var cells: [CardDebugGridCell] = []
        for row in placement.row..<(placement.row + gridBox.rowSpan) {
            for column in placement.column..<(placement.column + gridBox.columnSpan) {
                cells.append(CardDebugGridCell(column: column, row: row))
            }
        }
        return cells
    }

    var gridOverflow: Bool {
        guard let placement = layout.gridPlacement else { return false }
        return placement.column + gridBox.columnSpan > MemoryCardRecipeLayoutPolicy.columnCount
    }

    var debugLine: String {
        let placement = layout.gridPlacement.map { "c\($0.column)r\($0.row)" } ?? "nil"
        return "\(item.title) \(layout.size.rawValue) \(placement) \(gridBox.columnSpan)x\(gridBox.rowSpan) frame=\(Int(frame.width))x\(Int(frame.height))"
    }
}

struct CardDebugGridBoardLabReport: Hashable {
    let projectionMode: CardDebugGridBoardPlacementMode
    let boardWidth: CGFloat
    let cellSize: CGFloat
    let activeDragTarget: MemoryCardGridPlacement?
    let lastInsertionIndex: Int?
    let movedRange: ClosedRange<Int>?
    let rowCount: Int
    let occupiedCells: Int
    let totalCells: Int
    let holesCount: Int
    let autoPackRecoverableHoles: Int
    let density: Double
    let overlapCount: Int
    let gridOverflowCount: Int
    let slots: [CardDebugGridBoardLabSlot]

    var densityLabel: String {
        "\(Int((density * 100).rounded()))%"
    }

    var activeDragTargetLabel: String {
        activeDragTarget.map { "c\($0.column) r\($0.row)" } ?? "none"
    }

    var insertionIndexLabel: String {
        lastInsertionIndex.map(String.init) ?? "none"
    }

    var movedRangeLabel: String {
        guard let movedRange else { return "none" }
        return movedRange.lowerBound == movedRange.upperBound
            ? "\(movedRange.lowerBound)"
            : "\(movedRange.lowerBound)...\(movedRange.upperBound)"
    }
}

struct CardDebugGridDragPreview: Hashable {
    let itemID: UUID
    let targetPlacement: MemoryCardGridPlacement
    let insertionIndex: Int
    let movedRange: ClosedRange<Int>?
    let items: [CardDebugGridBoardLabItem]
}

struct CardDebugGridDragGeometry: Hashable {
    let originalFrame: CGRect
    let grabOffset: CGPoint

    init(originalFrame: CGRect, touchLocation: CGPoint) {
        self.originalFrame = originalFrame
        self.grabOffset = CGPoint(
            x: touchLocation.x - originalFrame.minX,
            y: touchLocation.y - originalFrame.minY
        )
    }

    func liftedFrame(for touchLocation: CGPoint) -> CGRect {
        CGRect(
            x: touchLocation.x - grabOffset.x,
            y: touchLocation.y - grabOffset.y,
            width: originalFrame.width,
            height: originalFrame.height
        )
    }

    func gridAnchorLocation(for touchLocation: CGPoint) -> CGPoint {
        CGPoint(
            x: touchLocation.x - grabOffset.x,
            y: touchLocation.y - grabOffset.y
        )
    }
}

struct CardDebugGridUIKitDragSession {
    let itemID: UUID
    let itemSize: MemoryCardSizeToken
    let geometry: CardDebugGridDragGeometry
}

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
    let affectedItemIDs: [UUID]
    let rowCount: Int
    let occupiedCells: Int
    let totalCells: Int
    let density: Double
    let overlapCount: Int
    let gridOverflowCount: Int
    let solverCost: CardDebugGridLayoutCost?
    let solverUsedFallback: Bool
    let slots: [CardDebugGridBoardLabSlot]

    var densityLabel: String {
        "\(Int((density * 100).rounded()))%"
    }

    var activeDragTargetLabel: String {
        activeDragTarget.map { "c\($0.column) r\($0.row)" } ?? "none"
    }

    var affectedLabel: String {
        affectedItemIDs.isEmpty ? "none" : "\(affectedItemIDs.count) item(s)"
    }

    var solverCostLabel: String {
        guard let solverCost else { return "none" }
        return "moved=\(solverCost.movedItemCount) pinned=\(solverCost.pinnedMovedCount) adjusted=\(solverCost.userAdjustedMovedCount) distance=\(solverCost.totalManhattanDistance) inversions=\(solverCost.visualOrderInversionCount)"
    }
}

struct CardDebugGridDragPreview: Hashable {
    let itemID: UUID
    let targetPlacement: MemoryCardGridPlacement
    let items: [CardDebugGridBoardLabItem]
    let affectedItemIDs: [UUID]
    let solverCost: CardDebugGridLayoutCost?
    let usedFallback: Bool

    init(
        itemID: UUID,
        targetPlacement: MemoryCardGridPlacement,
        items: [CardDebugGridBoardLabItem],
        affectedItemIDs: [UUID],
        solverCost: CardDebugGridLayoutCost? = nil,
        usedFallback: Bool = false
    ) {
        self.itemID = itemID
        self.targetPlacement = targetPlacement
        self.items = items
        self.affectedItemIDs = affectedItemIDs
        self.solverCost = solverCost
        self.usedFallback = usedFallback
    }
}

struct CardDebugGridLayoutCandidate: Hashable {
    let itemID: UUID
    let placement: MemoryCardGridPlacement
}

struct CardDebugGridLayoutState: Hashable {
    var placementsByID: [UUID: MemoryCardGridPlacement]
}

struct CardDebugGridLayoutSolverResult: Hashable {
    let state: CardDebugGridLayoutState
    let cost: CardDebugGridLayoutCost
    let usedFallback: Bool
}

struct CardDebugGridLayoutCost: Hashable, Comparable {
    let movedItemCount: Int
    let pinnedMovedCount: Int
    let userAdjustedMovedCount: Int
    let totalManhattanDistance: Int
    let totalRowDelta: Int
    let totalColumnDelta: Int
    let visualOrderInversionCount: Int
    let boardHeightGrowth: Int
    let tieBreakSignature: String

    static func < (lhs: CardDebugGridLayoutCost, rhs: CardDebugGridLayoutCost) -> Bool {
        if lhs.movedItemCount != rhs.movedItemCount {
            return lhs.movedItemCount < rhs.movedItemCount
        }
        if lhs.pinnedMovedCount != rhs.pinnedMovedCount {
            return lhs.pinnedMovedCount < rhs.pinnedMovedCount
        }
        if lhs.userAdjustedMovedCount != rhs.userAdjustedMovedCount {
            return lhs.userAdjustedMovedCount < rhs.userAdjustedMovedCount
        }
        if lhs.totalManhattanDistance != rhs.totalManhattanDistance {
            return lhs.totalManhattanDistance < rhs.totalManhattanDistance
        }
        if lhs.totalRowDelta != rhs.totalRowDelta {
            return lhs.totalRowDelta < rhs.totalRowDelta
        }
        if lhs.totalColumnDelta != rhs.totalColumnDelta {
            return lhs.totalColumnDelta < rhs.totalColumnDelta
        }
        if lhs.visualOrderInversionCount != rhs.visualOrderInversionCount {
            return lhs.visualOrderInversionCount < rhs.visualOrderInversionCount
        }
        if lhs.boardHeightGrowth != rhs.boardHeightGrowth {
            return lhs.boardHeightGrowth < rhs.boardHeightGrowth
        }
        return lhs.tieBreakSignature < rhs.tieBreakSignature
    }
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

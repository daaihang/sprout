import SwiftUI

enum CardDebugGridBoardPlacementMode: String, CaseIterable, Identifiable {
    case storedPlacement = "Stored Interactive"
    case nilPlacementFallback = "Nil Legacy"
    case firstFitEffectivePlacement = "First Fit"

    var id: String { rawValue }
}

enum CardDebugVisualStyle: String, CaseIterable, Identifiable {
    case circleBadge
    case emojiSticker
    case capsule
    case paperNote
    case photoTile
    case moodCircle
    case borderlessCutout
    case memoryCard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .circleBadge:
            return "Circle Badge"
        case .emojiSticker:
            return "Emoji Sticker"
        case .capsule:
            return "Capsule"
        case .paperNote:
            return "Paper Note"
        case .photoTile:
            return "Photo Tile"
        case .moodCircle:
            return "Mood Circle"
        case .borderlessCutout:
            return "Cutout"
        case .memoryCard:
            return "Memory Card"
        }
    }

    var symbolName: String {
        switch self {
        case .circleBadge:
            return "person.crop.circle"
        case .emojiSticker:
            return "face.smiling"
        case .capsule:
            return "capsule"
        case .paperNote:
            return "note.text"
        case .photoTile:
            return "photo"
        case .moodCircle:
            return "circle.hexagongrid.fill"
        case .borderlessCutout:
            return "scissors"
        case .memoryCard:
            return "sparkles.rectangle.stack"
        }
    }

    static func defaultStyle(for size: MemoryCardSizeToken) -> CardDebugVisualStyle {
        switch size {
        case .stamp:
            return .circleBadge
        case .strip:
            return .capsule
        case .card:
            return .memoryCard
        }
    }
}

struct CardDebugVisualDescriptor: Hashable {
    var style: CardDebugVisualStyle
    var title: String
    var symbolName: String
    var tintSeed: Int

    init(
        style: CardDebugVisualStyle,
        title: String,
        symbolName: String? = nil,
        tintSeed: Int
    ) {
        self.style = style
        self.title = title
        self.symbolName = symbolName ?? style.symbolName
        self.tintSeed = tintSeed
    }
}

struct CardDebugGridBoardLabItem: Identifiable, Hashable {
    var layout: MoryBoardLayoutItem<UUID>
    var visual: CardDebugVisualDescriptor

    var id: UUID {
        layout.id
    }

    var title: String {
        get { visual.title }
        set { visual.title = newValue }
    }

    var size: MemoryCardSizeToken {
        get { MemoryCardSizeToken(boardGridSize: layout.size) }
        set { layout.size = newValue.boardGridSize }
    }

    var placement: MemoryCardGridPlacement? {
        get { MemoryCardGridPlacement(column: layout.x, row: layout.y) }
        set {
            guard let newValue else { return }
            layout.x = newValue.column
            layout.y = newValue.row
        }
    }

    var recipe: MemoryCardVisualRecipe {
        CardDebugGridBoardLabModel.recipe(for: size)
    }

    var isPinned: Bool {
        get { layout.isPinned }
        set { layout.isPinned = newValue }
    }

    var isUserAdjusted: Bool {
        get { layout.isUserAdjusted }
        set { layout.isUserAdjusted = newValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        size: MemoryCardSizeToken,
        recipe: MemoryCardVisualRecipe = .statusNote,
        placement: MemoryCardGridPlacement? = nil,
        visualStyle: CardDebugVisualStyle? = nil,
        isPinned: Bool = false,
        isUserAdjusted: Bool = false
    ) {
        let point = placement ?? MemoryCardGridPlacement(column: 0, row: 0)
        let style = visualStyle ?? CardDebugVisualStyle.defaultStyle(for: size)
        self.layout = MoryBoardLayoutItem(
            id: id,
            x: point.column,
            y: point.row,
            w: size.boardGridSize.w,
            h: size.boardGridSize.h,
            isPinned: isPinned,
            isUserAdjusted: isUserAdjusted
        )
        self.visual = CardDebugVisualDescriptor(
            style: style,
            title: title,
            symbolName: recipe.debugFallbackSymbolName ?? style.symbolName,
            tintSeed: id.stableDebugTintSeed
        )
    }

    init(layout: MoryBoardLayoutItem<UUID>, visual: CardDebugVisualDescriptor) {
        self.layout = layout
        self.visual = visual
    }
}

struct CardDebugGridBoardLabSlot: Identifiable, Hashable {
    let id: UUID
    let item: CardDebugGridBoardLabItem
    let layout: MemoryCardLayoutToken
    let gridFrame: CGRect
    let renderFrame: CGRect
    let hitFrame: CGRect

    init(
        id: UUID,
        item: CardDebugGridBoardLabItem,
        layout: MemoryCardLayoutToken,
        frame: CGRect
    ) {
        self.init(
            id: id,
            item: item,
            layout: layout,
            gridFrame: frame,
            renderFrame: Self.renderFrame(for: frame, size: layout.size),
            hitFrame: frame
        )
    }

    init(
        id: UUID,
        item: CardDebugGridBoardLabItem,
        layout: MemoryCardLayoutToken,
        gridFrame: CGRect,
        renderFrame: CGRect,
        hitFrame: CGRect
    ) {
        self.id = id
        self.item = item
        self.layout = layout
        self.gridFrame = gridFrame
        self.renderFrame = renderFrame
        self.hitFrame = hitFrame
    }

    var frame: CGRect {
        gridFrame
    }

    var contentInsetsInRenderFrame: EdgeInsets {
        EdgeInsets(
            top: max(0, gridFrame.minY - renderFrame.minY),
            leading: max(0, gridFrame.minX - renderFrame.minX),
            bottom: max(0, renderFrame.maxY - gridFrame.maxY),
            trailing: max(0, renderFrame.maxX - gridFrame.maxX)
        )
    }

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
        return "\(item.title) \(layout.size.rawValue) \(placement) xywh=\(item.layout.x)/\(item.layout.y)/\(item.layout.w)/\(item.layout.h) style=\(item.visual.style.rawValue) pinned=\(item.isPinned) user=\(item.isUserAdjusted) grid=\(Int(gridFrame.width))x\(Int(gridFrame.height)) render=\(Int(renderFrame.width))x\(Int(renderFrame.height))"
    }

    private static func renderFrame(for gridFrame: CGRect, size: MemoryCardSizeToken) -> CGRect {
        gridFrame.insetBy(dx: -renderOverflowMargin(for: size), dy: -renderOverflowMargin(for: size))
    }

    private static func renderOverflowMargin(for size: MemoryCardSizeToken) -> CGFloat {
        switch size {
        case .stamp:
            return 8
        case .strip:
            return 10
        case .card:
            return 12
        }
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
    let originalGridFrame: CGRect
    let grabOffset: CGPoint

    init(originalFrame: CGRect, touchLocation: CGPoint) {
        self.init(
            renderFrame: originalFrame,
            gridFrame: originalFrame,
            touchLocation: touchLocation
        )
    }

    init(renderFrame: CGRect, gridFrame: CGRect, touchLocation: CGPoint) {
        self.originalFrame = renderFrame
        self.originalGridFrame = gridFrame
        self.grabOffset = CGPoint(
            x: touchLocation.x - renderFrame.minX,
            y: touchLocation.y - renderFrame.minY
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
        let liftedFrame = liftedFrame(for: touchLocation)
        return CGPoint(
            x: liftedFrame.minX + originalGridFrame.minX - originalFrame.minX,
            y: liftedFrame.minY + originalGridFrame.minY - originalFrame.minY
        )
    }
}

struct CardDebugGridUIKitDragSession {
    let itemID: UUID
    let itemSize: MemoryCardSizeToken
    let geometry: CardDebugGridDragGeometry
}

extension MemoryCardSizeToken {
    var boardGridSize: MoryBoardGridSize {
        switch self {
        case .stamp:
            return .stamp
        case .strip:
            return .strip
        case .card:
            return .card
        }
    }

    init(boardGridSize: MoryBoardGridSize) {
        switch (boardGridSize.w, boardGridSize.h) {
        case (1, 1):
            self = .stamp
        case (2, 1):
            self = .strip
        default:
            self = .card
        }
    }
}

private extension UUID {
    var stableDebugTintSeed: Int {
        uuidString.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31) &+ Int(scalar.value)
        }
    }
}

private extension MemoryCardVisualRecipe {
    var debugFallbackSymbolName: String? {
        switch self {
        case .notebook:
            return "book.pages"
        case .polaroid, .filmFrame, .livePhotoPrint:
            return "photo"
        case .cassette:
            return "waveform"
        case .vinyl:
            return "music.note"
        case .mapTicket:
            return "mappin.and.ellipse"
        case .weatherStamp:
            return "cloud.sun"
        case .linkNote:
            return "link"
        case .taskNote:
            return "checklist"
        case .personCard:
            return "person.crop.circle"
        case .affectCard:
            return "heart"
        case .bundlePacket:
            return "square.stack.3d.up"
        case .statusNote:
            return "sparkles"
        }
    }
}

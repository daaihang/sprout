import Foundation

enum MemoryCardContentDensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case regular
    case expanded

    var id: String { rawValue }
}

struct MemoryCardGridBox: Codable, Hashable, Sendable {
    var columnSpan: Int
    var rowSpan: Int

    init(columnSpan: Int, rowSpan: Int) {
        self.columnSpan = max(1, min(MemoryCardRecipeLayoutPolicy.columnCount, columnSpan))
        self.rowSpan = max(1, rowSpan)
    }
}

struct MemoryCardGridPlacement: Codable, Hashable, Sendable {
    var column: Int
    var row: Int

    init(column: Int, row: Int) {
        self.column = max(0, min(MemoryCardRecipeLayoutPolicy.columnCount - 1, column))
        self.row = max(0, row)
    }
}

enum MemoryCardRecipeLayoutPolicy {
    static let columnCount = 6

    static func gridBox(for size: MemoryCardSizeToken) -> MemoryCardGridBox {
        switch size {
        case .stamp:
            return MemoryCardGridBox(columnSpan: 1, rowSpan: 1)
        case .strip:
            return MemoryCardGridBox(columnSpan: 2, rowSpan: 1)
        case .card:
            return MemoryCardGridBox(columnSpan: 3, rowSpan: 2)
        case .square:
            return MemoryCardGridBox(columnSpan: 3, rowSpan: 3)
        case .tape:
            return MemoryCardGridBox(columnSpan: 4, rowSpan: 2)
        case .banner:
            return MemoryCardGridBox(columnSpan: 6, rowSpan: 3)
        }
    }

    static func contentDensity(for size: MemoryCardSizeToken) -> MemoryCardContentDensity {
        switch size {
        case .stamp, .strip:
            return .compact
        case .card, .square, .tape:
            return .regular
        case .banner:
            return .expanded
        }
    }

    static func supportedSizes(for recipe: MemoryCardVisualRecipe) -> [MemoryCardSizeToken] {
        switch recipe {
        case .notebook:
            return [.card, .banner]
        case .polaroid, .livePhotoPrint:
            return [.square, .banner]
        case .filmFrame:
            return [.tape, .banner]
        case .cassette:
            return [.strip, .tape, .banner]
        case .vinyl:
            return [.strip, .tape]
        case .mapTicket:
            return [.card]
        case .weatherStamp, .affectCard, .statusNote:
            return [.stamp, .strip]
        case .linkNote:
            return [.card, .banner]
        case .taskNote:
            return [.strip, .card]
        case .personCard:
            return [.strip, .card]
        case .bundlePacket:
            return [.card, .square]
        }
    }

    static func defaultSize(for recipe: MemoryCardVisualRecipe) -> MemoryCardSizeToken {
        switch recipe {
        case .notebook:
            return .card
        case .polaroid, .livePhotoPrint:
            return .square
        case .filmFrame, .cassette:
            return .tape
        case .vinyl:
            return .tape
        case .mapTicket, .linkNote, .personCard, .bundlePacket:
            return .card
        case .taskNote:
            return .strip
        case .weatherStamp, .affectCard, .statusNote:
            return .stamp
        }
    }

    static func normalizedSize(_ size: MemoryCardSizeToken, for recipe: MemoryCardVisualRecipe) -> MemoryCardSizeToken {
        supportedSizes(for: recipe).contains(size) ? size : defaultSize(for: recipe)
    }
}

enum MemoryCardGridPacking {
    static func placements(for sizes: [MemoryCardSizeToken]) -> [MemoryCardGridPlacement] {
        var occupiedRows: [[Bool]] = []
        var placements: [MemoryCardGridPlacement] = []

        for size in sizes {
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
            var row = 0
            var placement: MemoryCardGridPlacement?

            while placement == nil {
                ensureRows(upTo: row + box.rowSpan, rows: &occupiedRows)

                for column in 0...(MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan) {
                    guard canPlace(box: box, atRow: row, column: column, rows: occupiedRows) else {
                        continue
                    }
                    mark(box: box, atRow: row, column: column, rows: &occupiedRows)
                    placement = MemoryCardGridPlacement(column: column, row: row)
                    break
                }

                if placement == nil {
                    row += 1
                }
            }

            if let placement {
                placements.append(placement)
            }
        }

        return placements
    }

    static func requiredRowCount(for layouts: [MemoryCardLayoutToken]) -> Int {
        layouts.map { layout in
            let placement = layout.gridPlacement ?? MemoryCardGridPlacement(column: 0, row: layout.order)
            return placement.row + MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size).rowSpan
        }
        .max() ?? 0
    }

    private static func ensureRows(upTo count: Int, rows: inout [[Bool]]) {
        guard rows.count < count else { return }
        let row = Array(repeating: false, count: MemoryCardRecipeLayoutPolicy.columnCount)
        rows.append(contentsOf: Array(repeating: row, count: count - rows.count))
    }

    private static func canPlace(box: MemoryCardGridBox, atRow row: Int, column: Int, rows: [[Bool]]) -> Bool {
        for rowIndex in row..<(row + box.rowSpan) {
            for columnIndex in column..<(column + box.columnSpan) {
                if rows[rowIndex][columnIndex] {
                    return false
                }
            }
        }
        return true
    }

    private static func mark(box: MemoryCardGridBox, atRow row: Int, column: Int, rows: inout [[Bool]]) {
        for rowIndex in row..<(row + box.rowSpan) {
            for columnIndex in column..<(column + box.columnSpan) {
                rows[rowIndex][columnIndex] = true
            }
        }
    }
}

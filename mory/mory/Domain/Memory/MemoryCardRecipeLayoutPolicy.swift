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
    static let columnCount = 4

    static func gridBox(for size: MemoryCardSizeToken) -> MemoryCardGridBox {
        switch size {
        case .stamp:
            return MemoryCardGridBox(columnSpan: 1, rowSpan: 1)
        case .strip:
            return MemoryCardGridBox(columnSpan: 2, rowSpan: 1)
        case .card:
            return MemoryCardGridBox(columnSpan: 2, rowSpan: 2)
        }
    }

    static func contentDensity(for size: MemoryCardSizeToken) -> MemoryCardContentDensity {
        switch size {
        case .stamp, .strip:
            return .compact
        case .card:
            return .regular
        }
    }

    static func supportedSizes(for recipe: MemoryCardVisualRecipe) -> [MemoryCardSizeToken] {
        switch recipe {
        case .notebook:
            return [.card]
        case .polaroid, .livePhotoPrint:
            return [.card]
        case .filmFrame:
            return [.card]
        case .cassette:
            return [.strip, .card]
        case .vinyl:
            return [.strip, .card]
        case .mapTicket, .linkNote, .personCard:
            return [.strip, .card]
        case .affectCard, .statusNote:
            return [.stamp, .strip]
        case .weatherStamp:
            return [.stamp, .strip, .card]
        case .taskNote:
            return [.strip, .card]
        case .bundlePacket:
            return [.card]
        }
    }

    static func defaultSize(for recipe: MemoryCardVisualRecipe) -> MemoryCardSizeToken {
        switch recipe {
        case .notebook, .polaroid, .livePhotoPrint, .filmFrame, .mapTicket, .linkNote, .personCard, .bundlePacket:
            return .card
        case .cassette, .vinyl, .taskNote:
            return .strip
        case .weatherStamp, .affectCard, .statusNote:
            return .stamp
        }
    }

    static func normalizedSize(_ size: MemoryCardSizeToken, for recipe: MemoryCardVisualRecipe) -> MemoryCardSizeToken {
        supportedSizes(for: recipe).contains(size) ? size : defaultSize(for: recipe)
    }

    static func supportedVariants(
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> [MemoryCardVisualVariant] {
        let normalizedSize = normalizedSize(size, for: recipe)
        guard recipe == .weatherStamp else {
            return [.automatic]
        }

        switch normalizedSize {
        case .stamp:
            return [.automatic, .weatherIcon, .weatherTemperature, .weatherHumidity, .weatherWind]
        case .strip:
            return [.automatic, .weatherIconTemperature]
        case .card:
            return [.automatic, .weatherFullMetrics]
        }
    }

    static func defaultVariant(
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> MemoryCardVisualVariant {
        let normalizedSize = normalizedSize(size, for: recipe)
        guard recipe == .weatherStamp else {
            return .automatic
        }

        switch normalizedSize {
        case .stamp:
            return .weatherIcon
        case .strip:
            return .weatherIconTemperature
        case .card:
            return .weatherFullMetrics
        }
    }

    static func normalizedVariant(
        _ variant: MemoryCardVisualVariant?,
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> MemoryCardVisualVariant? {
        guard let variant, variant != .automatic else {
            return nil
        }
        if supportedVariants(for: recipe, size: size).contains(variant) {
            return variant
        }
        let fallback = defaultVariant(for: recipe, size: size)
        return fallback == .automatic ? nil : fallback
    }

    static func resolvedVariant(
        _ variant: MemoryCardVisualVariant?,
        for recipe: MemoryCardVisualRecipe,
        size: MemoryCardSizeToken
    ) -> MemoryCardVisualVariant {
        if let normalized = normalizedVariant(variant, for: recipe, size: size) {
            return normalized
        }
        return defaultVariant(for: recipe, size: size)
    }
}

enum MemoryCardGridPacking {
    static func placements(for sizes: [MemoryCardSizeToken]) -> [MemoryCardGridPlacement] {
        effectivePlacements(
            for: sizes.enumerated().map { index, size in
                MemoryCardLayoutToken(order: index, size: size)
            }
        )
    }

    static func placements(
        for sizes: [MemoryCardSizeToken],
        pinned: [Int: MemoryCardGridPlacement]
    ) -> [MemoryCardGridPlacement] {
        var occupiedRows: [[Bool]] = []
        var placements = Array<MemoryCardGridPlacement?>(repeating: nil, count: sizes.count)

        for index in pinned.keys.sorted() {
            guard sizes.indices.contains(index), let placement = pinned[index] else { continue }
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: sizes[index])
            ensureRows(upTo: placement.row + box.rowSpan, rows: &occupiedRows)
            mark(box: box, placement: placement, rows: &occupiedRows)
            placements[index] = placement
        }

        for (index, size) in sizes.enumerated() where placements[index] == nil {
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
            placements[index] = firstAvailablePlacement(for: box, rows: &occupiedRows)
        }

        return placements.compactMap { $0 }
    }

    static func effectivePlacements(for layouts: [MemoryCardLayoutToken]) -> [MemoryCardGridPlacement] {
        var occupiedRows: [[Bool]] = []
        var placements: [MemoryCardGridPlacement] = []

        for layout in layouts {
            let box = MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size)
            if let storedPlacement = layout.gridPlacement {
                ensureRows(upTo: storedPlacement.row + box.rowSpan, rows: &occupiedRows)
                mark(box: box, placement: storedPlacement, rows: &occupiedRows)
                placements.append(storedPlacement)
                continue
            }

            let placement = firstAvailablePlacement(for: box, rows: &occupiedRows)
            placements.append(placement)
        }

        return placements
    }

    static func requiredRowCount(for layouts: [MemoryCardLayoutToken]) -> Int {
        let placements = effectivePlacements(for: layouts)
        return zip(layouts, placements).map { layout, placement in
            return placement.row + MemoryCardRecipeLayoutPolicy.gridBox(for: layout.size).rowSpan
        }
        .max() ?? 0
    }

    private static func firstAvailablePlacement(
        for box: MemoryCardGridBox,
        rows: inout [[Bool]]
    ) -> MemoryCardGridPlacement {
        var row = 0
        while true {
            ensureRows(upTo: row + box.rowSpan, rows: &rows)

            for column in 0...(MemoryCardRecipeLayoutPolicy.columnCount - box.columnSpan) {
                guard canPlace(box: box, atRow: row, column: column, rows: rows) else {
                    continue
                }
                let placement = MemoryCardGridPlacement(column: column, row: row)
                mark(box: box, placement: placement, rows: &rows)
                return placement
            }

            row += 1
        }
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

    private static func mark(box: MemoryCardGridBox, placement: MemoryCardGridPlacement, rows: inout [[Bool]]) {
        for rowIndex in placement.row..<(placement.row + box.rowSpan) {
            for columnIndex in placement.column..<min(MemoryCardRecipeLayoutPolicy.columnCount, placement.column + box.columnSpan) {
                rows[rowIndex][columnIndex] = true
            }
        }
    }
}

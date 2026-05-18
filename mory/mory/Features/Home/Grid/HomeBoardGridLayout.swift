import SwiftUI

nonisolated struct HomeBoardGridPlacement: Hashable, Sendable {
    var index: Int
    var column: Int
    var row: Int
    var span: HomeBoardSpan
}

nonisolated struct HomeBoardGridPacking: Sendable {
    static func pack(spans: [HomeBoardSpan], columns: Int) -> [HomeBoardGridPlacement] {
        let columnCount = max(1, columns)
        var occupiedRows: [[Bool]] = []
        var placements: [HomeBoardGridPlacement] = []

        for (index, rawSpan) in spans.enumerated() {
            let span = rawSpan.clamped(to: columnCount)
            var row = 0
            var placed: HomeBoardGridPlacement?

            while placed == nil {
                ensureRows(upTo: row + span.heightUnits, columns: columnCount, rows: &occupiedRows)

                for column in 0...(columnCount - span.widthColumns) {
                    guard canPlace(span: span, atRow: row, column: column, rows: occupiedRows) else {
                        continue
                    }
                    mark(span: span, atRow: row, column: column, rows: &occupiedRows)
                    placed = HomeBoardGridPlacement(index: index, column: column, row: row, span: span)
                    break
                }

                if placed == nil {
                    row += 1
                }
            }

            if let placed {
                placements.append(placed)
            }
        }

        return placements
    }

    static func requiredRowCount(for placements: [HomeBoardGridPlacement]) -> Int {
        placements.map { $0.row + $0.span.heightUnits }.max() ?? 0
    }

    private static func ensureRows(upTo count: Int, columns: Int, rows: inout [[Bool]]) {
        guard rows.count < count else { return }
        rows.append(contentsOf: Array(repeating: Array(repeating: false, count: columns), count: count - rows.count))
    }

    private static func canPlace(span: HomeBoardSpan, atRow row: Int, column: Int, rows: [[Bool]]) -> Bool {
        for rowIndex in row..<(row + span.heightUnits) {
            for columnIndex in column..<(column + span.widthColumns) {
                if rows[rowIndex][columnIndex] {
                    return false
                }
            }
        }
        return true
    }

    private static func mark(span: HomeBoardSpan, atRow row: Int, column: Int, rows: inout [[Bool]]) {
        for rowIndex in row..<(row + span.heightUnits) {
            for columnIndex in column..<(column + span.widthColumns) {
                rows[rowIndex][columnIndex] = true
            }
        }
    }
}

nonisolated struct HomeBoardSpanKey: LayoutValueKey {
    static let defaultValue = HomeBoardSpan(widthColumns: 2, heightUnits: 1)
}

struct HomeBoardGridLayout: Layout {
    var metrics: HomeBoardGridMetrics

    init(metrics: HomeBoardGridMetrics) {
        self.metrics = metrics
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? metrics.minimumCellWidth * CGFloat(metrics.columns)
        let cellLength = metrics.cellLength(for: width)
        let placements = placements(for: subviews)
        let rowCount = HomeBoardGridPacking.requiredRowCount(for: placements)
        let height = CGFloat(rowCount) * cellLength + CGFloat(max(0, rowCount - 1)) * metrics.spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cellLength = metrics.cellLength(for: bounds.width)
        let placements = placements(for: subviews)

        for placement in placements {
            guard subviews.indices.contains(placement.index) else { continue }
            let x = bounds.minX + CGFloat(placement.column) * (cellLength + metrics.spacing)
            let y = bounds.minY + CGFloat(placement.row) * (cellLength + metrics.spacing)
            let width = CGFloat(placement.span.widthColumns) * cellLength
                + CGFloat(max(0, placement.span.widthColumns - 1)) * metrics.spacing
            let height = CGFloat(placement.span.heightUnits) * cellLength
                + CGFloat(max(0, placement.span.heightUnits - 1)) * metrics.spacing

            subviews[placement.index].place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }

    private func placements(for subviews: Subviews) -> [HomeBoardGridPlacement] {
        let spans = subviews.map { $0[HomeBoardSpanKey.self] }
        return HomeBoardGridPacking.pack(spans: spans, columns: metrics.columns)
    }
}

import SwiftUI

struct StickerGridSpanKey: LayoutValueKey {
    nonisolated static let defaultValue = ContainerSpan(widthColumns: 4, heightUnits: 4)
}

struct StickerGridLayout: Layout {
    let columns: Int

    init(columns: Int = 8) {
        self.columns = max(columns, 1)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? GridConfig.maxContentWidth
        let frames = layout(subviews: subviews, width: width)
        let maxY = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: maxY)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = layout(subviews: subviews, width: bounds.width)

        for (index, subview) in subviews.enumerated() {
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> [CGRect] {
        let unitWidth = GridConfig.unitWidth(contentWidth: width, columns: columns)
        let spanGap = GridConfig.columnSpacing
        var occupancy: [[Bool]] = []
        var result: [CGRect] = []

        for subview in subviews {
            let span = normalizedSpan(subview[StickerGridSpanKey.self])
            let spanColumns = min(span.widthColumns, columns)
            let spanRows = max(span.heightUnits, 1)
            let spanSize = span.size(unitWidth: unitWidth)
            let slot = firstFitPosition(
                columns: spanColumns,
                rows: spanRows,
                totalColumns: columns,
                occupancy: &occupancy
            )
            let x = CGFloat(slot.column) * (unitWidth + spanGap)
            let y = CGFloat(slot.row) * (unitWidth + spanGap)
            let frame = CGRect(x: x, y: y, width: spanSize.width, height: spanSize.height)

            result.append(frame)
        }

        return result
    }

    private func firstFitPosition(
        columns spanColumns: Int,
        rows spanRows: Int,
        totalColumns: Int,
        occupancy: inout [[Bool]]
    ) -> (row: Int, column: Int) {
        guard spanColumns <= totalColumns else { return (0, 0) }

        var row = 0
        while true {
            ensureRows(row + spanRows, totalColumns: totalColumns, occupancy: &occupancy)
            for column in 0...(totalColumns - spanColumns) {
                if canPlace(
                    atRow: row,
                    column: column,
                    width: spanColumns,
                    height: spanRows,
                    occupancy: occupancy
                ) {
                    occupy(
                        atRow: row,
                        column: column,
                        width: spanColumns,
                        height: spanRows,
                        occupancy: &occupancy
                    )
                    return (row, column)
                }
            }
            row += 1
        }
    }

    private func ensureRows(_ count: Int, totalColumns: Int, occupancy: inout [[Bool]]) {
        while occupancy.count < count {
            occupancy.append(Array(repeating: false, count: totalColumns))
        }
    }

    private func canPlace(
        atRow row: Int,
        column: Int,
        width: Int,
        height: Int,
        occupancy: [[Bool]]
    ) -> Bool {
        for checkRow in row..<(row + height) {
            for checkColumn in column..<(column + width) {
                if occupancy[checkRow][checkColumn] {
                    return false
                }
            }
        }
        return true
    }

    private func occupy(
        atRow row: Int,
        column: Int,
        width: Int,
        height: Int,
        occupancy: inout [[Bool]]
    ) {
        for fillRow in row..<(row + height) {
            for fillColumn in column..<(column + width) {
                occupancy[fillRow][fillColumn] = true
            }
        }
    }

    private func normalizedSpan(_ span: ContainerSpan) -> ContainerSpan {
        ContainerSpan(
            widthColumns: nearest(span.widthColumns, values: [2, 4, 6, 8]),
            heightUnits: nearest(span.heightUnits, values: [1, 2, 4])
        )
    }

    private func nearest(_ value: Int, values: [Int]) -> Int {
        values.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }
}

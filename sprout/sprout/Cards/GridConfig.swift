import SwiftUI

// MARK: - Grid Configuration

struct GridConfig {
    static let horizontalPadding: CGFloat = 12
    static let columnSpacing: CGFloat = 0
    static let containerPadding: CGFloat = 4
    static let cardCornerRadius: CGFloat = 20

    // Max unit width to prevent cards from being too wide on large screens
    static let maxUnitWidth: CGFloat = 50

    // Min column count (iPhone)
    static let minColumnCount: Int = 8
    // Max column count (iPad/large screens)
    static let maxColumnCount: Int = 16

    // Safety cap on total grid content width (Mac Catalyst / very wide iPad)
    static let maxContentWidth: CGFloat = 960

    // Calculate adaptive column count based on screen width
    static func adaptiveColumnCount(screenWidth: CGFloat) -> Int {
        let availableWidth = gridWidth(screenWidth: screenWidth)
        let unitWithSpacing = maxUnitWidth + columnSpacing
        let columns = Int(availableWidth / unitWithSpacing)
        return max(minColumnCount, min(columns, maxColumnCount))
    }

    static func gridWidth(screenWidth: CGFloat) -> CGFloat {
        min(screenWidth - horizontalPadding * 2, maxContentWidth)
    }

    // Calculate unit width based on screen width (adaptive)
    static func unitWidth(screenWidth: CGFloat) -> CGFloat {
        let columns = adaptiveColumnCount(screenWidth: screenWidth)
        let totalSpacing = columnSpacing * CGFloat(columns - 1)
        let width = (gridWidth(screenWidth: screenWidth) - totalSpacing) / CGFloat(columns)
        return min(width, maxUnitWidth)
    }

    static func unitWidth(contentWidth: CGFloat, columns: Int) -> CGFloat {
        let totalSpacing = columnSpacing * CGFloat(max(columns - 1, 0))
        return (contentWidth - totalSpacing) / CGFloat(columns)
    }
}

// MARK: - Container Span (multi-width support)

struct ContainerSpan: Equatable, Hashable {
    let widthColumns: Int   // 2, 4, 6, 8
    let heightUnits: Int    // 1, 2, 4

    func size(unitWidth: CGFloat) -> CGSize {
        let width = unitWidth * CGFloat(widthColumns) + GridConfig.columnSpacing * CGFloat(max(widthColumns - 1, 0))
        let height = unitWidth * CGFloat(heightUnits) + GridConfig.columnSpacing * CGFloat(max(heightUnits - 1, 0))
        return CGSize(width: width, height: height)
    }
}

// MARK: - Card Size Limits

struct CardSizeLimits: Equatable {
    let minWidth: Int
    let maxWidth: Int
    let minHeight: Int
    let maxHeight: Int

    func isValid(_ span: ContainerSpan) -> Bool {
        allowedWidths.contains(span.widthColumns) &&
        allowedHeights.contains(span.heightUnits)
    }

    var defaultSpan: ContainerSpan {
        let width = allowedWidths[max(0, allowedWidths.count / 2)]
        let height = allowedHeights[max(0, allowedHeights.count / 2)]
        return ContainerSpan(widthColumns: width, heightUnits: height)
    }

    var allowedWidths: [Int] {
        [2, 4, 6, 8].filter { $0 >= minWidth && $0 <= maxWidth }
    }

    var allowedHeights: [Int] {
        [1, 2, 4].filter { $0 >= minHeight && $0 <= maxHeight }
    }

    var allSpans: [ContainerSpan] {
        allowedWidths.flatMap { width in
            allowedHeights.map { height in
                ContainerSpan(widthColumns: width, heightUnits: height)
            }
        }
    }

    func clamped(span: ContainerSpan) -> ContainerSpan {
        let width = allowedWidths.last(where: { $0 <= span.widthColumns }) ?? allowedWidths.first ?? minWidth
        let height = allowedHeights.last(where: { $0 <= span.heightUnits }) ?? allowedHeights.first ?? minHeight
        return ContainerSpan(widthColumns: width, heightUnits: height)
    }
}

// Card type size limits - defines which sizes each card type can use
let cardSizeLimits: [String: CardSizeLimits] = [
    "emotion":  CardSizeLimits(minWidth: 2, maxWidth: 4, minHeight: 1, maxHeight: 2),
    "music":    CardSizeLimits(minWidth: 2, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "audio":    CardSizeLimits(minWidth: 4, maxWidth: 6, minHeight: 1, maxHeight: 4),
    "people":   CardSizeLimits(minWidth: 2, maxWidth: 6, minHeight: 1, maxHeight: 4),
    "today_in_history": CardSizeLimits(minWidth: 4, maxWidth: 8, minHeight: 1, maxHeight: 4),
    "photo":    CardSizeLimits(minWidth: 4, maxWidth: 8, minHeight: 2, maxHeight: 4),
    "weather":  CardSizeLimits(minWidth: 4, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "activity": CardSizeLimits(minWidth: 4, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "quote":    CardSizeLimits(minWidth: 4, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "todo":     CardSizeLimits(minWidth: 4, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "link":     CardSizeLimits(minWidth: 4, maxWidth: 6, minHeight: 2, maxHeight: 4),
    "map":      CardSizeLimits(minWidth: 4, maxWidth: 6, minHeight: 2, maxHeight: 4),
    "book":     CardSizeLimits(minWidth: 2, maxWidth: 4, minHeight: 1, maxHeight: 4),
    "film":     CardSizeLimits(minWidth: 4, maxWidth: 6, minHeight: 1, maxHeight: 4),
    "text":     CardSizeLimits(minWidth: 4, maxWidth: 8, minHeight: 1, maxHeight: 4),
]

func sizeLimits(for cardType: String) -> CardSizeLimits {
    cardSizeLimits[cardType] ?? CardSizeLimits(minWidth: 4, maxWidth: 4, minHeight: 1, maxHeight: 4)
}

func availableSpans(for cardType: String) -> [ContainerSpan] {
    sizeLimits(for: cardType).allSpans.sorted {
        if $0.widthColumns == $1.widthColumns {
            return $0.heightUnits < $1.heightUnits
        }
        return $0.widthColumns < $1.widthColumns
    }
}

// MARK: - Card Background Modifier

private struct CardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let radius = GridConfig.cardCornerRadius
        content
            // Light: near-opaque white  |  Dark: elevated system surface
            .background(
                colorScheme == .dark
                    ? Color(uiColor: .secondarySystemBackground).opacity(0.92)
                    : Color.white.opacity(0.90)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // Light: subtle drop shadow  |  Dark: none (invisible on dark bg) + hairline border instead
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.055),
                radius: 12, x: 0, y: 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.07) : Color.clear,
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func cardBackground() -> some View {
        modifier(CardBackgroundModifier())
    }
}

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
    let heightUnits: Int    // 1, 2, 4, 6

    func size(unitWidth: CGFloat) -> CGSize {
        let width = unitWidth * CGFloat(widthColumns) + GridConfig.columnSpacing * CGFloat(max(widthColumns - 1, 0))
        let height = unitWidth * CGFloat(heightUnits) + GridConfig.columnSpacing * CGFloat(max(heightUnits - 1, 0))
        return CGSize(width: width, height: height)
    }
}

// MARK: - Card Size Limits

struct CardSizeLimits: Equatable {
    let allowedSpans: [ContainerSpan]

    func isValid(_ span: ContainerSpan) -> Bool {
        allowedSpans.contains(span)
    }

    var defaultSpan: ContainerSpan {
        if allowedSpans.contains(ContainerSpan(widthColumns: 4, heightUnits: 4)) {
            return ContainerSpan(widthColumns: 4, heightUnits: 4)
        }

        return allowedSpans.first ?? ContainerSpan(widthColumns: 4, heightUnits: 4)
    }

    var allowedWidths: [Int] {
        Array(Set(allowedSpans.map(\.widthColumns))).sorted()
    }

    var allowedHeights: [Int] {
        Array(Set(allowedSpans.map(\.heightUnits))).sorted()
    }

    var allSpans: [ContainerSpan] {
        allowedSpans.sorted {
            if $0.widthColumns == $1.widthColumns {
                return $0.heightUnits < $1.heightUnits
            }
            return $0.widthColumns < $1.widthColumns
        }
    }

    func clamped(span: ContainerSpan) -> ContainerSpan {
        guard let bestMatch = allowedSpans.min(by: { lhs, rhs in
            let lhsDistance = abs(lhs.widthColumns - span.widthColumns) + abs(lhs.heightUnits - span.heightUnits)
            let rhsDistance = abs(rhs.widthColumns - span.widthColumns) + abs(rhs.heightUnits - span.heightUnits)
            if lhsDistance == rhsDistance {
                if lhs.widthColumns == rhs.widthColumns {
                    return lhs.heightUnits < rhs.heightUnits
                }
                return lhs.widthColumns < rhs.widthColumns
            }
            return lhsDistance < rhsDistance
        }) else {
            return span
        }

        return bestMatch
    }
}

let globalAllowedCardSpans: [ContainerSpan] = {
    let widths = [2, 4, 6, 8]
    let heights = [1, 2, 4, 6]
    let forbidden: Set<ContainerSpan> = [
        ContainerSpan(widthColumns: 2, heightUnits: 1),
        ContainerSpan(widthColumns: 2, heightUnits: 6),
        ContainerSpan(widthColumns: 8, heightUnits: 1),
        ContainerSpan(widthColumns: 8, heightUnits: 6),
    ]

    return widths.flatMap { width in
        heights.map { height in
            ContainerSpan(widthColumns: width, heightUnits: height)
        }
    }
    .filter { !forbidden.contains($0) }
}()

let sharedCardSizeLimits = CardSizeLimits(allowedSpans: globalAllowedCardSpans)

// Card type size limits - currently unified for all card types.
let cardSizeLimits: [String: CardSizeLimits] = [
    "emotion": sharedCardSizeLimits,
    "music": sharedCardSizeLimits,
    "audio": sharedCardSizeLimits,
    "people": sharedCardSizeLimits,
    "today_in_history": sharedCardSizeLimits,
    "photo": sharedCardSizeLimits,
    "weather": sharedCardSizeLimits,
    "activity": sharedCardSizeLimits,
    "quote": sharedCardSizeLimits,
    "todo": sharedCardSizeLimits,
    "link": sharedCardSizeLimits,
    "map": sharedCardSizeLimits,
    "book": sharedCardSizeLimits,
    "film": sharedCardSizeLimits,
    "text": sharedCardSizeLimits,
]

func sizeLimits(for cardType: String) -> CardSizeLimits {
    cardSizeLimits[cardType] ?? sharedCardSizeLimits
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

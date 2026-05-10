import SwiftUI

// MARK: - Grid Configuration

struct GridConfig {
    static let horizontalPadding: CGFloat = 16
    static let columnSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 20

    // Base unit size (both width and height)
    static let unitSize: CGFloat = 40

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
        let availableWidth = screenWidth - horizontalPadding * 2
        let unitWithSpacing = maxUnitWidth + columnSpacing
        let columns = Int(availableWidth / unitWithSpacing)
        return max(minColumnCount, min(columns, maxColumnCount))
    }

    static func gridWidth(screenWidth: CGFloat) -> CGFloat {
        screenWidth - horizontalPadding * 2
    }

    // Calculate unit width based on screen width (adaptive)
    static func unitWidth(screenWidth: CGFloat) -> CGFloat {
        let columns = adaptiveColumnCount(screenWidth: screenWidth)
        let totalSpacing = columnSpacing * CGFloat(columns - 1)
        let width = (gridWidth(screenWidth: screenWidth) - totalSpacing) / CGFloat(columns)
        return min(width, maxUnitWidth)
    }
}

// MARK: - Card Size

struct CardSize: Equatable {
    let columns: Int
    let units: Int

    func width(columnWidth: CGFloat) -> CGFloat {
        columnWidth * CGFloat(columns) + GridConfig.columnSpacing * CGFloat(columns - 1)
    }

    func height(columnWidth: CGFloat) -> CGFloat {
        columnWidth * CGFloat(units)
    }

    // Computed size based on a default screen width
    static let defaultScreenWidth: CGFloat = 393

    var width: CGFloat {
        let colWidth = GridConfig.unitWidth(screenWidth: Self.defaultScreenWidth)
        return width(columnWidth: colWidth)
    }

    var height: CGFloat {
        let colWidth = GridConfig.unitWidth(screenWidth: Self.defaultScreenWidth)
        return height(columnWidth: colWidth)
    }

    static let w4h1 = CardSize(columns: 4, units: 1)
    static let w4h2 = CardSize(columns: 4, units: 2)
    static let w4h4 = CardSize(columns: 4, units: 4)
}

// MARK: - Card Modifier

extension View {
    func cardBackground() -> some View {
        self
            .background(Color.white.opacity(0.90))
            .clipShape(RoundedRectangle(cornerRadius: GridConfig.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 4)
    }
}
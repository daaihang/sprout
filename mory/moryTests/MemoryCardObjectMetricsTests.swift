import XCTest
@testable import mory

final class MemoryCardObjectMetricsTests: XCTestCase {
    func testMetricsExistForEverySupportedRecipeSize() {
        for recipe in MemoryCardVisualRecipe.allCases {
            for size in MemoryCardRecipeLayoutPolicy.supportedSizes(for: recipe) {
                let metrics = MemoryCardObjectMetrics.resolve(recipe: recipe, sizeToken: size)

                XCTAssertEqual(metrics.recipe, recipe)
                XCTAssertEqual(metrics.sizeToken, size)
                XCTAssertEqual(metrics.density, MemoryCardRecipeLayoutPolicy.contentDensity(for: size))
                XCTAssertGreaterThan(metrics.preferredSize.width, 0, "\(recipe.rawValue).\(size.rawValue)")
                XCTAssertGreaterThan(metrics.preferredSize.height, 0, "\(recipe.rawValue).\(size.rawValue)")
                XCTAssertGreaterThanOrEqual(metrics.padding.top, 0)
                XCTAssertGreaterThanOrEqual(metrics.titleLineLimit, 1)
                XCTAssertGreaterThanOrEqual(metrics.detailLineLimit, 1)
                XCTAssertGreaterThanOrEqual(metrics.metadataLineLimit, 1)
            }
        }
    }

    func testUnsupportedSizeNormalizesBeforeResolvingMetrics() {
        let affect = MemoryCardObjectMetrics.resolve(recipe: .affectCard, sizeToken: .card)
        XCTAssertEqual(affect.sizeToken, .stamp)
        XCTAssertEqual(affect.density, .compact)

        let map = MemoryCardObjectMetrics.resolve(recipe: .mapTicket, sizeToken: .stamp)
        XCTAssertEqual(map.sizeToken, .card)
        XCTAssertEqual(map.density, .regular)
    }

    func testObjectSizeIsIndependentFromGridBoxSpan() {
        let size = MemoryCardRecipeLayoutPolicy.gridBox(for: .stamp)
        let metrics = MemoryCardObjectMetrics.resolve(recipe: .affectCard, sizeToken: .stamp)

        XCTAssertEqual(size, MemoryCardGridBox(columnSpan: 1, rowSpan: 1))
        XCTAssertGreaterThan(metrics.preferredSize.width, 1)
        XCTAssertGreaterThan(metrics.preferredSize.height, 1)
    }

    func testFittedObjectSizesStayNearGridAcrossBoardMetrics() {
        let surfaces: [(String, CGFloat, MemoryDeskBoardMetrics)] = [
            ("detail", 393, .default),
            ("composer", 393, .compactComposer),
            ("debugPhone", 393, .debugSquare(availableWidth: 393)),
            ("debugWide", 620, .debugSquare(availableWidth: 620)),
        ]

        for recipe in MemoryCardVisualRecipe.allCases {
            for size in MemoryCardRecipeLayoutPolicy.supportedSizes(for: recipe) {
                for surface in surfaces {
                    let availableSize = gridSize(for: size, containerWidth: surface.1, metrics: surface.2)
                    let metrics = MemoryCardObjectMetrics.resolve(
                        recipe: recipe,
                        sizeToken: size,
                        availableSize: availableSize
                    )
                    let widthRatio = metrics.preferredSize.width / availableSize.width
                    let heightRatio = metrics.preferredSize.height / availableSize.height
                    let label = "\(surface.0) \(recipe.rawValue).\(size.rawValue)"

                    XCTAssertGreaterThanOrEqual(widthRatio, 0.70, label)
                    XCTAssertGreaterThanOrEqual(heightRatio, 0.70, label)
                    XCTAssertLessThanOrEqual(widthRatio, 1.33, label)
                    XCTAssertLessThanOrEqual(heightRatio, 1.33, label)
                }
            }
        }
    }
}

private func gridSize(
    for size: MemoryCardSizeToken,
    containerWidth: CGFloat,
    metrics: MemoryDeskBoardMetrics
) -> CGSize {
    let cellWidth = metrics.cellWidth(for: containerWidth)
    let box = MemoryCardRecipeLayoutPolicy.gridBox(for: size)
    return CGSize(
        width: CGFloat(box.columnSpan) * cellWidth + CGFloat(max(0, box.columnSpan - 1)) * metrics.columnSpacing,
        height: CGFloat(box.rowSpan) * metrics.rowHeight + CGFloat(max(0, box.rowSpan - 1)) * metrics.rowSpacing
    )
}

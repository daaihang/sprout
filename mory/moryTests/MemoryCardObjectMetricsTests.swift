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
        let weather = MemoryCardObjectMetrics.resolve(recipe: .weatherStamp, sizeToken: .banner)
        XCTAssertEqual(weather.sizeToken, .stamp)
        XCTAssertEqual(weather.density, .compact)

        let map = MemoryCardObjectMetrics.resolve(recipe: .mapTicket, sizeToken: .tape)
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
}

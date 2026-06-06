import CoreGraphics
import XCTest
@testable import mory

final class MemoryCardObjectMetricsTests: XCTestCase {
    func testMetricsResolveForEveryRecipeAndSupportedDensity() {
        for recipe in MemoryCardVisualRecipe.allCases {
            for density in MemoryCardRecipeLayoutPolicy.supportedDensities(for: recipe) {
                let metrics = MemoryCardObjectMetrics.resolve(recipe: recipe, density: density)
                XCTAssertEqual(metrics.recipe, recipe)
                XCTAssertEqual(metrics.density, density)
                XCTAssertGreaterThan(metrics.preferredSize.width, 0)
                XCTAssertGreaterThan(metrics.preferredSize.height, 0)
                XCTAssertGreaterThan(metrics.padding.top, 0)
                XCTAssertGreaterThanOrEqual(metrics.titleLineLimit, 1)
                XCTAssertGreaterThanOrEqual(metrics.detailLineLimit, 1)
            }
        }
    }

    func testAvailableWidthControlsPreferredWidth() {
        let metrics = MemoryCardObjectMetrics.resolve(
            recipe: .linkNote,
            density: .regular,
            availableSize: CGSize(width: 180, height: 240)
        )
        XCTAssertEqual(metrics.preferredSize.width, 180)
        XCTAssertLessThanOrEqual(metrics.preferredSize.height, 240)
    }

    func testEstimatedHeightUsesRecipeAndDensity() {
        let compact = MemoryCardObjectMetrics.estimatedHeight(for: .notebook, density: .regular, columnWidth: 180)
        let expanded = MemoryCardObjectMetrics.estimatedHeight(for: .notebook, density: .expanded, columnWidth: 180)
        XCTAssertGreaterThan(expanded, compact)
    }

    func testMediaRecipesUseFillThumbnailScale() {
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(recipe: .polaroid).thumbnailScale, .fill)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(recipe: .filmFrame).thumbnailScale, .fill)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(recipe: .weatherStamp, density: .compact).thumbnailScale, .none)
    }
}

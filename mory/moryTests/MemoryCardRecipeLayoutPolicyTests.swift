import XCTest
@testable import mory

@MainActor
final class MemoryCardRecipeLayoutPolicyTests: XCTestCase {
    func testGridBoxAndDensityMappings() {
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .stamp), MemoryCardGridBox(columnSpan: 1, rowSpan: 1))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .strip), MemoryCardGridBox(columnSpan: 2, rowSpan: 1))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .card), MemoryCardGridBox(columnSpan: 3, rowSpan: 2))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .square), MemoryCardGridBox(columnSpan: 3, rowSpan: 3))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .tape), MemoryCardGridBox(columnSpan: 4, rowSpan: 2))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.gridBox(for: .banner), MemoryCardGridBox(columnSpan: 6, rowSpan: 3))

        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .stamp), .compact)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .strip), .compact)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .card), .regular)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .square), .regular)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .tape), .regular)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.contentDensity(for: .banner), .expanded)
    }

    func testEachRecipeHasSupportedAndDefaultSize() {
        for recipe in MemoryCardVisualRecipe.allCases {
            let supported = MemoryCardRecipeLayoutPolicy.supportedSizes(for: recipe)
            let `default` = MemoryCardRecipeLayoutPolicy.defaultSize(for: recipe)

            XCTAssertFalse(supported.isEmpty, "Expected supported sizes for \(recipe.rawValue)")
            XCTAssertTrue(supported.contains(`default`), "Expected default size to be supported for \(recipe.rawValue)")
        }
    }

    func testRecipeSupportedSizesMatchPolicyContract() {
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .cassette), [.strip, .tape, .banner])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .weatherStamp), [.stamp, .strip, .card])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .affectCard), [.stamp, .strip])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .statusNote), [.stamp, .strip])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .linkNote), [.card, .banner])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .polaroid), [.square, .banner])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedSizes(for: .mapTicket), [.card])
    }

    func testNormalizedSizeFallsBackToDefaultWhenUnsupported() {
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedSize(.banner, for: .mapTicket), .card)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedSize(.stamp, for: .notebook), .card)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedSize(.tape, for: .weatherStamp), .stamp)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedSize(.strip, for: .cassette), .strip)
    }

    func testWeatherVariantSupportAndDefaults() {
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.supportedVariants(for: .weatherStamp, size: .stamp),
            [.automatic, .weatherIcon, .weatherTemperature, .weatherHumidity, .weatherWind]
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.supportedVariants(for: .weatherStamp, size: .strip),
            [.automatic, .weatherIconTemperature]
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.supportedVariants(for: .weatherStamp, size: .card),
            [.automatic, .weatherFullMetrics]
        )

        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.defaultVariant(for: .weatherStamp, size: .stamp), .weatherIcon)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.defaultVariant(for: .weatherStamp, size: .strip), .weatherIconTemperature)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.defaultVariant(for: .weatherStamp, size: .card), .weatherFullMetrics)
    }

    func testVariantNormalizationAndResolution() {
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.normalizedVariant(.automatic, for: .weatherStamp, size: .stamp),
            nil
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.normalizedVariant(.weatherHumidity, for: .weatherStamp, size: .stamp),
            .weatherHumidity
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.normalizedVariant(.weatherWind, for: .weatherStamp, size: .strip),
            .weatherIconTemperature
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.resolvedVariant(nil, for: .weatherStamp, size: .card),
            .weatherFullMetrics
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.supportedVariants(for: .cassette, size: .tape),
            [.automatic]
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.resolvedVariant(.weatherHumidity, for: .cassette, size: .tape),
            .automatic
        )
    }
}

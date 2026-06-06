import XCTest
@testable import mory

final class MemoryCardRecipeLayoutPolicyTests: XCTestCase {
    func testDefaultDensityIsSupportedForEveryRecipe() {
        for recipe in MemoryCardVisualRecipe.allCases {
            let supported = MemoryCardRecipeLayoutPolicy.supportedDensities(for: recipe)
            let defaultDensity = MemoryCardRecipeLayoutPolicy.defaultDensity(for: recipe)
            XCTAssertTrue(supported.contains(defaultDensity), "\(recipe.rawValue) default density must be supported")
        }
    }

    func testRecipeSpecificDensitySupport() {
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedDensities(for: .notebook), [.regular, .expanded])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedDensities(for: .weatherStamp), [.compact, .regular])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedDensities(for: .affectCard), [.compact, .regular])
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.supportedDensities(for: .cassette), MemoryCardContentDensity.allCases)
    }

    func testDensityNormalizationFallsBackToRecipeDefault() {
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedDensity(.compact, for: .notebook), .expanded)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedDensity(.expanded, for: .weatherStamp), .compact)
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.normalizedDensity(.regular, for: .cassette), .regular)
    }

    func testWeatherVariantsFollowDensity() {
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.defaultVariant(for: .weatherStamp, density: .compact),
            .weatherIcon
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.defaultVariant(for: .weatherStamp, density: .regular),
            .weatherIconTemperature
        )
        XCTAssertEqual(
            MemoryCardRecipeLayoutPolicy.resolvedVariant(.weatherFullMetrics, for: .weatherStamp, density: .compact),
            .weatherIcon
        )
    }

    func testNonWeatherVariantsResolveToAutomatic() {
        XCTAssertNil(MemoryCardRecipeLayoutPolicy.normalizedVariant(.weatherIcon, for: .cassette, density: .compact))
        XCTAssertEqual(MemoryCardRecipeLayoutPolicy.resolvedVariant(nil, for: .cassette, density: .compact), .automatic)
    }
}

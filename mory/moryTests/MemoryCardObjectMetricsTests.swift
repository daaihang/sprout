import CoreGraphics
import XCTest
@testable import mory

final class MemoryCardObjectMetricsTests: XCTestCase {
    func testMetricsResolveForEveryContentKindAndSupportedDensity() {
        for contentKind in MemoryCardContentKind.allCases {
            for density in MemoryCardPresentationPolicy.supportedDensities(for: contentKind) {
                let metrics = MemoryCardObjectMetrics.resolve(contentKind: contentKind, density: density)
                XCTAssertEqual(metrics.contentKind, contentKind)
                XCTAssertEqual(metrics.density, density)
                XCTAssertGreaterThan(metrics.preferredSize.width, 0)
                XCTAssertGreaterThan(metrics.preferredSize.height, 0)
                if [.photo, .video, .livePhoto].contains(contentKind) {
                    XCTAssertEqual(metrics.padding.top, 0)
                    XCTAssertEqual(metrics.titleLineLimit, 0)
                    XCTAssertEqual(metrics.detailLineLimit, 0)
                } else if contentKind == .place && density == .standard {
                    XCTAssertGreaterThan(metrics.padding.top, 0)
                    XCTAssertGreaterThanOrEqual(metrics.titleLineLimit, 1)
                    XCTAssertEqual(metrics.detailLineLimit, 0)
                } else {
                    XCTAssertGreaterThan(metrics.padding.top, 0)
                    XCTAssertGreaterThanOrEqual(metrics.titleLineLimit, 1)
                    XCTAssertGreaterThanOrEqual(metrics.detailLineLimit, 1)
                }
            }
        }
    }

    func testAvailableWidthControlsPreferredWidth() {
        let metrics = MemoryCardObjectMetrics.resolve(
            contentKind: .link,
            density: .standard,
            availableSize: CGSize(width: 180, height: 240)
        )
        XCTAssertEqual(metrics.preferredSize.width, 180)
        XCTAssertLessThanOrEqual(metrics.preferredSize.height, 240)
    }

    func testEstimatedHeightUsesContentKindAndDensity() {
        let simple = MemoryCardObjectMetrics.estimatedHeight(for: .recordBody, density: .simple, columnWidth: 180)
        let detailed = MemoryCardObjectMetrics.estimatedHeight(for: .recordBody, density: .detailed, columnWidth: 180)
        XCTAssertGreaterThan(detailed, simple)
    }

    func testThumbnailScaleDependsOnContentKindOnly() {
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .photo).thumbnailScale, .fill)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .video).thumbnailScale, .fill)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .weather, density: .simple).thumbnailScale, .none)
    }

    func testMediaHeightUsesClampedAspectRatio() {
        let wide = MemoryCardObjectMetrics.estimatedHeight(
            for: .photo,
            density: .standard,
            columnWidth: 180,
            mediaAspectRatio: 4
        )
        let tall = MemoryCardObjectMetrics.estimatedHeight(
            for: .video,
            density: .standard,
            columnWidth: 180,
            mediaAspectRatio: 0.2
        )

        XCTAssertEqual(wide, 180 / (16.0 / 9.0), accuracy: 0.1)
        XCTAssertEqual(tall, 180 / (9.0 / 16.0), accuracy: 0.1)
    }

    func testPlaceDensityRatiosAreExplicit() {
        let standard = MemoryCardObjectMetrics.estimatedHeight(for: .place, density: .standard, columnWidth: 180)
        let detailed = MemoryCardObjectMetrics.estimatedHeight(for: .place, density: .detailed, columnWidth: 180)

        XCTAssertEqual(standard, 135, accuracy: 0.1)
        XCTAssertEqual(detailed, 240, accuracy: 0.1)
    }

    func testTextDensityLineLimitsMatchPolicy() {
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .prompt, density: .standard).detailLineLimit, 4)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .prompt, density: .detailed).detailLineLimit, 6)
        XCTAssertEqual(MemoryCardObjectMetrics.resolve(contentKind: .affect, density: .simple).detailLineLimit, 1)
    }
}

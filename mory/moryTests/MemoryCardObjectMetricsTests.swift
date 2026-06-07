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
                XCTAssertGreaterThan(metrics.padding.top, 0)
                XCTAssertGreaterThanOrEqual(metrics.titleLineLimit, 1)
                XCTAssertGreaterThanOrEqual(metrics.detailLineLimit, 1)
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
}

import XCTest
@testable import mory

final class PlaceContextResolverTests: XCTestCase {
    func testNearbyCoordinatesMatchDespiteDifferentReverseGeocodeNames() {
        let lhs = locationArtifact(
            title: "Apple Park Visitor Center",
            latitude: 37.3328,
            longitude: -122.0054
        )
        let rhs = locationArtifact(
            title: "Tantau Avenue",
            latitude: 37.3331,
            longitude: -122.0051
        )

        XCTAssertTrue(PlaceContextResolver.isSamePlace(lhs, rhs))
    }

    func testSimilarNamesDoNotMatchWhenCoordinatesAreFarApart() {
        let lhs = locationArtifact(
            title: "Starbucks Nanjing West",
            latitude: 31.2299,
            longitude: 121.4548
        )
        let rhs = locationArtifact(
            title: "Starbucks Nanjing West",
            latitude: 39.9042,
            longitude: 116.4074
        )

        XCTAssertFalse(PlaceContextResolver.isSamePlace(lhs, rhs))
    }

    func testPartialNameMatchUsesCoordinateBoundedFuzzyMerge() {
        let lhs = locationArtifact(
            title: "星巴克 南京西路店",
            latitude: 31.2304,
            longitude: 121.4737
        )
        let rhs = locationArtifact(
            title: "星巴克南京西路",
            latitude: 31.2310,
            longitude: 121.4741
        )

        XCTAssertTrue(PlaceContextResolver.isSamePlace(lhs, rhs))
    }

    func testClustersSplitSameNameWhenCoordinatesAreFar() {
        let recordA = UUID()
        let recordB = UUID()
        let recordC = UUID()
        let entries = [
            PlaceContextEntry(
                artifact: locationArtifact(title: "Cafe", latitude: 31.2304, longitude: 121.4737),
                recordID: recordA
            ),
            PlaceContextEntry(
                artifact: locationArtifact(title: "Cafe entrance", latitude: 31.2307, longitude: 121.4739),
                recordID: recordB
            ),
            PlaceContextEntry(
                artifact: locationArtifact(title: "Cafe", latitude: 39.9042, longitude: 116.4074),
                recordID: recordC
            ),
        ]

        let clusters = PlaceContextResolver().clusters(from: entries)

        XCTAssertEqual(clusters.count, 2)
        XCTAssertTrue(clusters.contains { Set($0.recordIDs) == Set([recordA, recordB]) })
        XCTAssertTrue(clusters.contains { Set($0.recordIDs) == Set([recordC]) })
    }

    private func locationArtifact(title: String, latitude: Double, longitude: Double) -> Artifact {
        Artifact(
            recordID: UUID(),
            kind: .location,
            title: title,
            summary: title,
            textContent: title,
            payload: .metadata([
                "latitude": String(latitude),
                "longitude": String(longitude),
            ]),
            metadata: [
                "latitude": String(latitude),
                "longitude": String(longitude),
            ],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

import XCTest
@testable import mory

final class MemoryCardPresentationPolicyTests: XCTestCase {
    func testDefaultDensityIsSupportedForEveryContentKind() {
        for contentKind in MemoryCardContentKind.allCases {
            let supported = MemoryCardPresentationPolicy.supportedDensities(for: contentKind)
            let defaultDensity = MemoryCardPresentationPolicy.defaultDensity(for: contentKind)
            XCTAssertTrue(supported.contains(defaultDensity), "\(contentKind.rawValue) default density must be supported")
        }
    }

    func testContentKindSpecificDensitySupport() {
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .recordBody), MemoryCardContentDensity.allCases)
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .audio), MemoryCardContentDensity.allCases)
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .bundle), MemoryCardContentDensity.allCases)
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .weather), [.simple, .standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .affect), [.simple])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .status), [.simple, .standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .photo), [.standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .video), [.standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .livePhoto), [.standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .prompt), [.standard, .detailed])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .person), [.simple, .standard])
        XCTAssertEqual(MemoryCardPresentationPolicy.supportedDensities(for: .link), [.simple, .standard])
    }

    func testDensityNormalizationFallsBackToContentDefault() {
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.simple, for: .photo), .standard)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.detailed, for: .video), .standard)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.simple, for: .prompt), .detailed)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.detailed, for: .person), .standard)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.detailed, for: .link), .standard)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.standard, for: .affect), .simple)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.detailed, for: .weather), .simple)
        XCTAssertEqual(MemoryCardPresentationPolicy.normalizedDensity(.standard, for: .audio), .standard)
    }

    func testDraftAndArtifactDefaultsUseContentSemantics() {
        XCTAssertEqual(MemoryCardPresentationPolicy.defaultDensity(for: CaptureArtifactContent.audio(AudioArtifactContent(title: nil, summary: "", filename: "voice.caf"))), .simple)
        XCTAssertEqual(MemoryCardPresentationPolicy.defaultDensity(for: CaptureArtifactContent.text(TextArtifactContent(title: nil, body: "Long note"))), .detailed)

        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let photo = Artifact(recordID: UUID(), kind: .photo, title: "Photo", summary: "Photo", createdAt: now, updatedAt: now)
        let document = Artifact(recordID: UUID(), kind: .document, title: "Doc", summary: "Doc", createdAt: now, updatedAt: now)
        XCTAssertEqual(MemoryCardPresentationPolicy.defaultDensity(for: photo), .standard)
        XCTAssertEqual(MemoryCardPresentationPolicy.defaultDensity(for: document), .detailed)
    }
}

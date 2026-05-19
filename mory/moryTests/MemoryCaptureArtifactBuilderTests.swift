import XCTest
@testable import mory

final class MemoryCaptureArtifactBuilderTests: XCTestCase {
    func testBuildArtifactsPersistsCaptureOriginMetadata() throws {
        let builder = MemoryCaptureArtifactBuilder()
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let recordID = UUID()

        let draft = MemoryCaptureDraft(
            title: nil,
            rawText: "Memory body",
            captureSource: .composer,
            artifacts: [
                .text(title: nil, body: "Memory body", origin: .manual),
                .location(
                    title: "Cafe",
                    summary: "Nanjing Road",
                    latitude: 31.231,
                    longitude: 121.473,
                    origin: .context
                ),
                .todo(title: "Follow up", note: "Send recap", origin: .imported)
            ]
        )

        let artifacts = builder.buildArtifacts(from: draft, recordID: recordID, createdAt: createdAt)

        let text = try XCTUnwrap(artifacts.first(where: { $0.kind == .text }))
        XCTAssertEqual(text.metadata["captureOrigin"], CaptureArtifactOrigin.manual.rawValue)

        let location = try XCTUnwrap(artifacts.first(where: { $0.kind == .location }))
        XCTAssertEqual(location.metadata["captureOrigin"], CaptureArtifactOrigin.context.rawValue)

        let todo = try XCTUnwrap(artifacts.first(where: { $0.kind == .todo }))
        XCTAssertEqual(todo.metadata["captureOrigin"], CaptureArtifactOrigin.imported.rawValue)
    }
}

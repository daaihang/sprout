import XCTest
@testable import mory

final class AnalyzeRequestBuilderTests: XCTestCase {
    func testBuildUsesDocumentedRecordAggregateShape() throws {
        let now = Date(timeIntervalSince1970: 1_715_000_000)
        let record = RecordShell(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "Met Linh after dinner and wrote down the next quarter plan.",
            userMood: "reflective",
            userIntensity: 3,
            inputContext: "typed in composer",
            artifactIDs: [UUID(uuidString: "22222222-2222-2222-2222-222222222222")!]
        )
        let artifacts = [
            Artifact(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                recordID: record.id,
                kind: .text,
                title: "Dinner note",
                summary: "Quarter plan clicked into place",
                textContent: "Met Linh after dinner and wrote down the next quarter plan.",
                metadata: ["source": "composer"],
                createdAt: now,
                updatedAt: now
            )
        ]
        let knownEntities = [
            EntityReference(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                kind: .person,
                name: "Linh",
                aliases: ["Linh Tran"],
                confidence: 0.88
            )
        ]

        let payload = AnalyzeRequestBuilder().build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: "capture_ingest"
        )

        XCTAssertEqual(payload.schemaVersion, "record_aggregate.v1")
        XCTAssertEqual(payload.clientVersion, "mory.v3")
        XCTAssertEqual(payload.analysisReason, "capture_ingest")
        XCTAssertEqual(payload.recordShell.rawText, record.rawText)
        XCTAssertEqual(payload.recordShell.captureSource, "composer")
        XCTAssertEqual(payload.recordShell.userMood, "reflective")
        XCTAssertEqual(payload.recordShell.userIntensity, 3)
        XCTAssertEqual(payload.recordShell.inputContext, "typed in composer")
        XCTAssertEqual(payload.artifacts.count, 1)
        XCTAssertEqual(payload.artifacts.first?.kind, "text")
        XCTAssertEqual(payload.artifacts.first?.metadata["source"], "composer")
        XCTAssertEqual(payload.knownEntities.first?.kind, "person")
        XCTAssertEqual(payload.knownEntities.first?.name, "Linh")
    }

    func testBuildKeepsCanonicalAnalysisContractFields() throws {
        let now = Date(timeIntervalSince1970: 1_715_000_001)
        let record = RecordShell(
            createdAt: now,
            updatedAt: now,
            captureSource: .composer,
            rawText: "A local-first note.",
            userMood: nil,
            userIntensity: nil,
            inputContext: "debug"
        )

        let payload = AnalyzeRequestBuilder().build(
            record: record,
            artifacts: [],
            knownEntities: [],
            analysisReason: "preview"
        )

        XCTAssertEqual(payload.schemaVersion, "record_aggregate.v1")
        XCTAssertEqual(payload.analysisReason, "preview")
        XCTAssertEqual(payload.recordShell.rawText, "A local-first note.")
        XCTAssertEqual(payload.recordShell.captureSource, "composer")
        XCTAssertEqual(payload.knownEntities.count, 0)
        XCTAssertEqual(payload.artifacts.count, 0)
    }
}

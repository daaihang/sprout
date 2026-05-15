import XCTest
@testable import mory

final class AnalyzeResponseMapperTests: XCTestCase {
    func testDecodeAndMapServerResponseWithoutThemesField() throws {
        let json = """
        {
          "tags": ["journal", "gratitude"],
          "emotion": {
            "label": "positive",
            "intensity": 4,
            "confidence": 0.88
          },
          "entities": [
            {
              "kind": "person",
              "name": "Linh",
              "canonical_name": "Linh",
              "confidence": 0.91,
              "source_artifact_ids": ["a1"]
            },
            {
              "kind": "theme",
              "name": "gratitude",
              "canonical_name": "gratitude",
              "confidence": 0.83,
              "source_artifact_ids": []
            }
          ],
          "candidate_edges": [
            {
              "from_name": "Linh",
              "from_kind": "person",
              "to_name": "gratitude",
              "to_kind": "theme",
              "relation": "mentioned_with",
              "confidence": 0.72
            }
          ],
          "insight": "The note carries a clear positive signal and can anchor future reflection.",
          "summary": "A positive memory with gratitude and emotional lift.",
          "salience_score": 0.72,
          "retrieval_terms": ["gratitude", "positive_moment"],
          "reflection_hint": "Track whether gratitude clusters around the same people or settings.",
          "follow_up": {
            "question": "What part of this moment do you want to remember a month from now?"
          },
          "meta": {
            "provider": "mock",
            "model": "mock-analyzer-v1",
            "usage": {
              "input_tokens": 10,
              "output_tokens": 20
            }
          }
        }
        """

        let envelope = try JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: Data(json.utf8))
        let snapshot = AnalyzeResponseMapper().map(
            recordID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            response: envelope,
            createdAt: Date(timeIntervalSince1970: 1_715_000_100)
        )

        XCTAssertEqual(snapshot.summary, "A positive memory with gratitude and emotional lift.")
        XCTAssertEqual(snapshot.themes, ["gratitude", "journal"])
        XCTAssertEqual(snapshot.retrievalTerms, ["gratitude", "positive_moment", "journal", "Linh"])
        XCTAssertEqual(snapshot.entityMentions.count, 2)
        XCTAssertEqual(snapshot.candidateEdges.count, 1)
        XCTAssertEqual(snapshot.followUpCandidates.first?.prompt, "What part of this moment do you want to remember a month from now?")
        XCTAssertEqual(snapshot.reflectionHint, "Track whether gratitude clusters around the same people or settings.")
    }

    func testDecodeAndMapResponseWithoutTagsEntitiesAndRetrievalTerms() throws {
        let json = """
        {
          "emotion": {
            "label": "neutral"
          },
          "candidate_edges": [],
          "insight": "No strong pattern yet.",
          "summary": "",
          "follow_up": null,
          "meta": {
            "provider": "mock",
            "model": "mock-analyzer-v1",
            "usage": {
              "input_tokens": 5,
              "output_tokens": 8
            }
          }
        }
        """

        let envelope = try JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: Data(json.utf8))
        let snapshot = AnalyzeResponseMapper().map(
            recordID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            response: envelope,
            createdAt: Date(timeIntervalSince1970: 1_715_000_200)
        )

        XCTAssertEqual(snapshot.summary, "No strong pattern yet.")
        XCTAssertTrue(snapshot.themes.isEmpty)
        XCTAssertTrue(snapshot.retrievalTerms.isEmpty)
        XCTAssertEqual(snapshot.emotionInterpretation, "neutral")
        XCTAssertTrue(snapshot.entityMentions.isEmpty)
        XCTAssertTrue(snapshot.candidateEdges.isEmpty)
        XCTAssertTrue(snapshot.followUpCandidates.isEmpty)
    }
}

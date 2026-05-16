import XCTest
import UIKit
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

    func testFiltersTechnicalNoiseEntitiesAndEdges() throws {
        let json = """
        {
          "tags": ["theme", "OCR", "planning"],
          "emotion": {"label": "neutral"},
          "entities": [
            {"kind": "theme", "name": "theme", "confidence": 0.99},
            {"kind": "theme", "name": "OCR", "confidence": 0.99},
            {"kind": "theme", "name": "ORC", "confidence": 0.99},
            {"kind": "object", "name": "photo", "confidence": 0.99},
            {"kind": "theme", "name": "planning rhythm", "confidence": 0.82},
            {"kind": "person", "name": "Linh", "confidence": 0.91}
          ],
          "candidate_edges": [
            {"from_name": "OCR", "from_kind": "theme", "to_name": "Linh", "to_kind": "person", "relation": "related_to", "confidence": 0.92},
            {"from_name": "planning rhythm", "from_kind": "theme", "to_name": "Linh", "to_kind": "person", "relation": "related_to", "confidence": 0.92}
          ],
          "insight": "A useful planning note.",
          "summary": "A useful planning note.",
          "salience_score": 0.72,
          "retrieval_terms": ["OCR", "planning rhythm"],
          "reflection_hint": "Track whether planning rhythm repeats.",
          "follow_up": null
        }
        """

        let envelope = try JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: Data(json.utf8))
        let snapshot = AnalyzeResponseMapper().map(recordID: UUID(), response: envelope)

        XCTAssertEqual(Set(snapshot.entityMentions.map(\.name)), Set(["planning rhythm", "Linh"]))
        XCTAssertEqual(snapshot.candidateEdges.count, 1)
        XCTAssertEqual(snapshot.candidateEdges.first?.from.name, "planning rhythm")
        XCTAssertFalse(snapshot.themes.contains("theme"))
        XCTAssertFalse(snapshot.themes.contains("OCR"))
        XCTAssertFalse(snapshot.themes.contains("ORC"))
    }

    func testFiltersDebugTuningLabelsFromEntitiesAndThemeAnchors() throws {
        let json = """
        {
          "tags": ["quality tuning", "quality tuning lab", "receipt"],
          "emotion": {"label": "neutral"},
          "entities": [
            {"kind": "theme", "name": "quality tuning", "confidence": 0.99},
            {"kind": "theme", "name": "quality tuning lab", "confidence": 0.99},
            {"kind": "theme", "name": "debug scenario", "confidence": 0.99},
            {"kind": "theme", "name": "receipt review", "confidence": 0.82}
          ],
          "candidate_edges": [
            {"from_name": "quality tuning", "from_kind": "theme", "to_name": "receipt review", "to_kind": "theme", "relation": "related_to", "confidence": 0.92}
          ],
          "insight": "A receipt capture used for debug.",
          "summary": "A receipt capture used for debug.",
          "salience_score": 0.24,
          "retrieval_terms": ["quality tuning", "receipt"],
          "reflection_hint": "",
          "follow_up": null
        }
        """

        let envelope = try JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: Data(json.utf8))
        let snapshot = AnalyzeResponseMapper().map(recordID: UUID(), response: envelope)

        XCTAssertEqual(snapshot.entityMentions.map(\.name), ["receipt review"])
        XCTAssertTrue(snapshot.candidateEdges.isEmpty)

        let policy = EntityQualityPolicy(thresholds: .defaults)
        XCTAssertFalse(policy.usefulThemeLabel("quality tuning"))
        XCTAssertFalse(policy.usefulThemeLabel("quality tuning lab"))
        XCTAssertFalse(policy.usefulThemeLabel("debug scenario"))
    }

    func testDefaultArcPolicyRejectsWeakDebugScenarioCluster() throws {
        let candidate = TemporalArcCandidate(
            titleHint: "receipt / quality tuning",
            themeLabels: ["receipt"],
            entityNames: [],
            recordIDs: [UUID(), UUID()],
            artifactIDs: [],
            startDate: Date(timeIntervalSince1970: 1),
            endDate: Date(timeIntervalSince1970: 2),
            intensityScore: 4.5,
            clusterStrength: 0.474985
        )

        let result = ArcQualityPolicy(thresholds: .defaults).evaluate(candidate)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.reason, "cluster strength below threshold")
    }

    func testTagsDoNotFallbackIntoThemeEntitiesWhenEntitiesAreEmpty() throws {
        let json = """
        {
          "tags": ["planning", "reflection"],
          "emotion": {"label": "neutral"},
          "entities": [],
          "candidate_edges": [],
          "insight": "A small note.",
          "summary": "A small note.",
          "salience_score": 0.35,
          "retrieval_terms": ["planning"],
          "reflection_hint": "",
          "follow_up": null
        }
        """

        let envelope = try JSONDecoder().decode(AnalyzeResponseEnvelope.self, from: Data(json.utf8))
        let snapshot = AnalyzeResponseMapper().map(recordID: UUID(), response: envelope)

        XCTAssertTrue(snapshot.entityMentions.isEmpty)
        XCTAssertEqual(snapshot.themes, ["planning", "reflection"])
    }

    func testAnalyzeRequestBuilderIncludesPromptProfileDebugOption() throws {
        let previousEnabled = QualityTuningRuntime.isEnabled
        let previousProfile = QualityTuningRuntime.promptProfile
        QualityTuningRuntime.isEnabled = true
        QualityTuningRuntime.promptProfile = .strict
        defer {
            QualityTuningRuntime.isEnabled = previousEnabled
            QualityTuningRuntime.promptProfile = previousProfile
        }

        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Debug tuning payload."
        )
        let payload = AnalyzeRequestBuilder().build(record: record, artifacts: [])

        XCTAssertEqual(payload.debugOptions?.promptProfile, "strict")
    }

    func testAnalyzeRequestBuilderOmitsDebugOptionsByDefault() throws {
        let previousEnabled = QualityTuningRuntime.isEnabled
        QualityTuningRuntime.isEnabled = false
        defer { QualityTuningRuntime.isEnabled = previousEnabled }

        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Normal payload."
        )
        let payload = AnalyzeRequestBuilder().build(record: record, artifacts: [])

        XCTAssertNil(payload.debugOptions)
    }

    func testQualityTuningOverrideChangesEntityGateVerdict() throws {
        let entity = EntityReference(kind: .person, name: "Linh", aliases: [], confidence: 0.60)

        XCTAssertTrue(EntityQualityPolicy(thresholds: .defaults).evaluate(entity).passed)

        var strict = QualityTuningThresholds.defaults
        strict.entityMinimumConfidence = 0.80
        XCTAssertFalse(EntityQualityPolicy(thresholds: strict).evaluate(entity).passed)
    }

    func testPhotoArtifactProcessorHandlesVisionFailuresWithoutContinuationCrash() async throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let data = renderer.jpegData(withCompressionQuality: 0.8) { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.black.setFill()
            context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))
        }

        let result = await PhotoArtifactProcessor().process(imageData: data, filename: "debug.jpg")

        XCTAssertFalse(result.title.isEmpty)
        XCTAssertFalse(result.thumbnailData.isEmpty)
    }
}

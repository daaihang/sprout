import XCTest
import UIKit
@testable import mory

final class RecordAnalysisSnapshotMapperTests: XCTestCase {
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

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(
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

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(
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

    func testCanonicalEntityNameIsPreservedWithOriginalMentionAsAlias() throws {
        let json = """
        {
          "tags": ["launch plan"],
          "emotion": {"label": "focused"},
          "entities": [
            {
              "kind": "person",
              "name": "A. Chen",
              "canonical_name": "Alex Chen",
              "confidence": 0.9
            }
          ],
          "candidate_edges": [],
          "insight": "A. Chen confirmed the quieter launch plan.",
          "summary": "A. Chen confirmed the quieter launch plan.",
          "salience_score": 0.7,
          "retrieval_terms": ["A. Chen", "launch plan"],
          "reflection_hint": "Check whether this quieter launch plan keeps recurring."
        }
        """

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(recordID: UUID(), response: envelope)

        let person = try XCTUnwrap(snapshot.entityMentions.first)
        XCTAssertEqual(person.name, "Alex Chen")
        XCTAssertTrue(person.aliases.contains("A. Chen"))
        XCTAssertTrue(snapshot.retrievalTerms.contains("Alex Chen"))
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

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(recordID: UUID(), response: envelope)

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
            {"kind": "theme", "name": "pottery class", "confidence": 0.82}
          ],
          "candidate_edges": [
            {"from_name": "quality tuning", "from_kind": "theme", "to_name": "pottery class", "to_kind": "theme", "relation": "related_to", "confidence": 0.92}
          ],
          "insight": "A receipt capture used for debug.",
          "summary": "A receipt capture used for debug.",
          "salience_score": 0.24,
          "retrieval_terms": ["quality tuning", "receipt"],
          "reflection_hint": "",
          "follow_up": null
        }
        """

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(recordID: UUID(), response: envelope)

        XCTAssertEqual(snapshot.entityMentions.map(\.name), ["pottery class"])
        XCTAssertTrue(snapshot.candidateEdges.isEmpty)

        let policy = EntityQualityPolicy(thresholds: .defaults)
        XCTAssertFalse(policy.usefulThemeLabel("quality tuning"))
        XCTAssertFalse(policy.usefulThemeLabel("quality tuning lab"))
        XCTAssertFalse(policy.usefulThemeLabel("debug scenario"))
        XCTAssertFalse(policy.usefulThemeLabel("receipt review"))
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
            clusterStrength: 0.474985,
            averageSalience: 0.7
        )

        let result = ArcQualityPolicy(thresholds: .defaults).evaluate(candidate)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.reason, "cluster strength below threshold")
    }

    func testArcPolicyAllowsThreeRecordSemanticClusterWithModerateAverageSalience() throws {
        let candidate = TemporalArcCandidate(
            titleHint: "launch plan around Alexander Chen",
            themeLabels: ["launch plan", "check-in"],
            entityNames: ["Alexander Chen"],
            recordIDs: [UUID(), UUID(), UUID()],
            artifactIDs: [],
            startDate: Date(timeIntervalSince1970: 1),
            endDate: Date(timeIntervalSince1970: 3),
            intensityScore: 6,
            clusterStrength: 0.42,
            averageSalience: 0.48
        )

        let result = ArcQualityPolicy(thresholds: .defaults).evaluate(candidate)

        XCTAssertTrue(result.passed)
    }

    func testFocusedArcCandidateIncludesCurrentRecordAfterSimilarHistory() throws {
        let baseDate = Date(timeIntervalSince1970: 1_715_000_000)
        let recordIDs = [UUID(), UUID(), UUID()]
        let artifactIDs = [UUID(), UUID(), UUID()]
        let records = zip(recordIDs, artifactIDs).enumerated().map { index, pair in
            RecordShell(
                id: pair.0,
                createdAt: baseDate.addingTimeInterval(Double(index)),
                updatedAt: baseDate.addingTimeInterval(Double(index)),
                captureSource: .composer,
                rawText: [
                    "I noticed relief after admitting to Linh that the current launch scope is too wide.",
                    "During planning I chose the smaller launch scope and wrote down the roles I need to hand off.",
                    "Third note about the same career transition: I told Linh the smaller launch scope is the version I can actually stand behind.",
                ][index],
                artifactIDs: [pair.1]
            )
        }
        let artifacts = zip(records, artifactIDs).map { record, artifactID in
            Artifact(
                id: artifactID,
                recordID: record.id,
                kind: .text,
                title: "Career transition",
                summary: record.rawText,
                textContent: record.rawText,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
        let linhID = UUID()
        let entityNodes = [
            EntityNode(
                id: linhID,
                kind: .person,
                displayName: "Linh",
                provenanceRecordIDs: recordIDs,
                createdAt: baseDate,
                updatedAt: baseDate,
                confidence: 0.95
            )
        ]
        let links = zip(artifactIDs, recordIDs).map { artifactID, recordID in
            ArtifactEntityLink(
                artifactID: artifactID,
                entityID: linhID,
                confidence: 0.95,
                source: "analysis",
                sourceRecordID: recordID,
                createdAt: baseDate
            )
        }
        let analyses = recordIDs.map {
            RecordAnalysisSnapshot(
                recordID: $0,
                summary: "Career transition and launch scope.",
                themes: ["career transition", "launch scope"],
                emotionInterpretation: "focused",
                salienceScore: 0.7,
                createdAt: baseDate
            )
        }

        let candidates = TemporalArcCandidateBuilder().buildCandidates(
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: links,
            entityNodes: entityNodes,
            focusRecordID: recordIDs[2],
            maxCandidates: 3
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].recordIDs.contains(recordIDs[2]))
        XCTAssertGreaterThanOrEqual(Set(candidates[0].recordIDs).count, 2)
    }

    func testFocusedArcCandidateUsesSemanticRecurringAnchorsWithoutEntities() throws {
        let baseDate = Date(timeIntervalSince1970: 1_715_000_000)
        let recordIDs = [UUID(), UUID(), UUID()]
        let artifactIDs = [UUID(), UUID(), UUID()]
        let texts = [
            "In January I protected Monday morning for writing and finished the essay before meetings.",
            "In March I lost the morning block to meetings and the writing slipped again.",
            "Months later, the same pattern returned: when I protect the first morning block, writing actually happens before meetings.",
        ]
        let records = zip(recordIDs, artifactIDs).enumerated().map { index, pair in
            RecordShell(
                id: pair.0,
                createdAt: baseDate.addingTimeInterval(Double(index)),
                updatedAt: baseDate.addingTimeInterval(Double(index)),
                captureSource: .composer,
                rawText: texts[index],
                artifactIDs: [pair.1]
            )
        }
        let artifacts = zip(records, artifactIDs).map { record, artifactID in
            Artifact(
                id: artifactID,
                recordID: record.id,
                kind: .text,
                title: "Writing block",
                summary: record.rawText,
                textContent: record.rawText,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
        let analyses = recordIDs.map {
            RecordAnalysisSnapshot(
                recordID: $0,
                summary: "Morning writing block pattern.",
                themes: ["writing", "morning routine"],
                emotionInterpretation: "focused",
                salienceScore: 0.7,
                createdAt: baseDate
            )
        }

        let candidates = TemporalArcCandidateBuilder().buildCandidates(
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: [],
            entityNodes: [],
            focusRecordID: recordIDs[2],
            maxCandidates: 3
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(Set(candidate.recordIDs), Set(recordIDs))
        XCTAssertGreaterThanOrEqual(candidate.clusterStrength, 0.4)
        XCTAssertTrue(ArcQualityPolicy().evaluate(candidate).passed)
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

        let envelope = try JSONDecoder().decode(AnalysisRecordResponse.self, from: Data(json.utf8))
        let snapshot = RecordAnalysisSnapshotMapper().map(recordID: UUID(), response: envelope)

        XCTAssertTrue(snapshot.entityMentions.isEmpty)
        XCTAssertEqual(snapshot.themes, ["planning", "reflection"])
    }

    func testAnalysisRecordPayloadBuilderIncludesPromptProfileDebugOption() throws {
        let previousEnabled = QualityTuningRuntime.isEnabled
        let previousProfile = QualityTuningRuntime.promptProfile
        let previousScope = QualityTuningRuntime.activeRecordScope
        QualityTuningRuntime.isEnabled = true
        QualityTuningRuntime.promptProfile = .strict
        QualityTuningRuntime.activeRecordScope = []
        defer {
            QualityTuningRuntime.isEnabled = previousEnabled
            QualityTuningRuntime.promptProfile = previousProfile
            QualityTuningRuntime.activeRecordScope = previousScope
        }

        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Debug tuning payload."
        )
        let payload = AnalysisRecordPayloadBuilder().build(record: record, artifacts: [])

        XCTAssertEqual(payload.debugOptions?.promptProfile, "strict")
    }

    func testAnalysisRecordPayloadBuilderOmitsDebugOptionsByDefault() throws {
        let previousEnabled = QualityTuningRuntime.isEnabled
        QualityTuningRuntime.isEnabled = false
        defer { QualityTuningRuntime.isEnabled = previousEnabled }

        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Normal payload."
        )
        let payload = AnalysisRecordPayloadBuilder().build(record: record, artifacts: [])

        XCTAssertNil(payload.debugOptions)
    }

    func testQualityTuningOverrideChangesEntityGateVerdict() throws {
        let entity = EntityReference(kind: .person, name: "Linh", aliases: [], confidence: 0.60)

        XCTAssertTrue(EntityQualityPolicy(thresholds: .defaults).evaluate(entity).passed)

        var strict = QualityTuningThresholds.defaults
        strict.entityMinimumConfidence = 0.80
        XCTAssertFalse(EntityQualityPolicy(thresholds: strict).evaluate(entity).passed)
    }

    func testExplicitDecisionReflectionCanPassBelowDefaultSalienceFloor() throws {
        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "I spent the morning comparing two launch plans. I decided to protect scope early, and the smaller plan made me feel calmer about the next review."
        )
        let artifact = Artifact(
            recordID: record.id,
            kind: .text,
            title: "Launch decision",
            summary: record.rawText,
            textContent: record.rawText,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
        let analysis = RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "The user decided to protect launch scope and noticed calmer decision-making.",
            themes: ["launch scope", "decision-making", "scope protection"],
            emotionInterpretation: "reflective",
            salienceScore: 0.7,
            retrievalTerms: ["launch plan", "scope", "decision"],
            reflectionHint: "Consider how protecting scope early might apply to future launch decisions.",
            createdAt: record.updatedAt
        )

        let result = ReflectionQualityPolicy().shouldRequestRecordReflection(record: record, artifacts: [artifact], analysis: analysis)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.reason, "explicit decision reflection candidate")
    }

    func testNamedPlanPreferenceReflectionCanPassStrictSalienceFloorWithoutDisambiguationNoise() throws {
        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Third check-in with A. Chen confirmed that Alexander wants the quieter launch plan."
        )
        let artifact = Artifact(
            recordID: record.id,
            kind: .text,
            title: "Alias same person history",
            summary: record.rawText,
            textContent: record.rawText,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
        let analysis = RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "Third check-in with Alexander Chen confirmed preference for quieter launch plan.",
            themes: ["check-in", "launch plan"],
            emotionInterpretation: "focused",
            salienceScore: 0.6,
            retrievalTerms: ["Alexander Chen", "quieter launch plan"],
            createdAt: record.updatedAt
        )

        let result = ReflectionQualityPolicy().shouldRequestRecordReflection(record: record, artifacts: [artifact], analysis: analysis)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.reason, "named plan preference candidate")
    }

    func testNamedPlanPreferenceReflectionRejectsSameNameDisambiguationNoise() throws {
        let record = RecordShell(
            createdAt: .now,
            updatedAt: .now,
            captureSource: .composer,
            rawText: "Alex from pottery asked about the cracked bowl glaze, unrelated to Alex from work."
        )
        let artifact = Artifact(
            recordID: record.id,
            kind: .text,
            title: "Same-name different people",
            summary: record.rawText,
            textContent: record.rawText,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt
        )
        let analysis = RecordAnalysisSnapshot(
            recordID: record.id,
            summary: "The note distinguishes Alex from pottery from Alex from work.",
            themes: ["pottery", "same-name different people"],
            emotionInterpretation: "warm",
            salienceScore: 0.7,
            retrievalTerms: ["Alex", "pottery", "work"],
            createdAt: record.updatedAt
        )

        let result = ReflectionQualityPolicy().shouldRequestRecordReflection(record: record, artifacts: [artifact], analysis: analysis)

        XCTAssertFalse(result.passed)
    }

    func testAliasSamePersonHistoryBuildsArcCandidateWithModerateStrictSalience() throws {
        let baseDate = Date(timeIntervalSince1970: 1_715_000_000)
        let records = [
            RecordShell(createdAt: baseDate, updatedAt: baseDate, captureSource: .composer, rawText: "Alexander Chen said the current launch plan feels too loud and asked for a quieter rollout."),
            RecordShell(createdAt: baseDate.addingTimeInterval(60), updatedAt: baseDate.addingTimeInterval(60), captureSource: .composer, rawText: "Alex Chen repeated that the quieter launch plan would help the team finish carefully."),
            RecordShell(createdAt: baseDate.addingTimeInterval(120), updatedAt: baseDate.addingTimeInterval(120), captureSource: .composer, rawText: "Third check-in with A. Chen confirmed that Alexander wants the quieter launch plan.")
        ]
        let artifacts = records.map {
            Artifact(recordID: $0.id, kind: .text, title: "Alias", summary: $0.rawText, textContent: $0.rawText, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let entity = EntityNode(
            kind: .person,
            displayName: "Alexander Chen",
            aliases: ["Alex Chen", "A. Chen"],
            provenanceRecordIDs: records.map(\.id),
            createdAt: baseDate,
            updatedAt: baseDate,
            confidence: 0.9
        )
        let links = zip(artifacts, records).map { artifact, record in
            ArtifactEntityLink(
                artifactID: artifact.id,
                entityID: entity.id,
                confidence: 0.9,
                source: "analysis",
                sourceRecordID: record.id,
                sourceAnalysisRecordID: record.id,
                evidenceSummary: record.rawText,
                createdAt: record.createdAt
            )
        }
        let analyses = records.map {
            RecordAnalysisSnapshot(
                recordID: $0.id,
                summary: $0.rawText,
                themes: ["launch plan"],
                emotionInterpretation: "focused",
                salienceScore: 0.45,
                retrievalTerms: ["Alexander Chen", "quieter launch plan"],
                createdAt: $0.updatedAt
            )
        }

        let candidates = TemporalArcCandidateBuilder().buildCandidates(
            records: records,
            analyses: analyses,
            artifacts: artifacts,
            artifactEntityLinks: links,
            entityNodes: [entity],
            focusRecordID: records.last?.id,
            maxCandidates: 3
        )

        let candidate = try XCTUnwrap(candidates.first)
        XCTAssertEqual(Set(candidate.recordIDs), Set(records.map(\.id)))
        XCTAssertTrue(ArcQualityPolicy().evaluate(candidate).passed)
    }

    func testQualityTuningPresetMatrixCoversInputAndHistoryVariation() throws {
        let scenarios = QualityTuningScenarioID.allCases.map(QualityTuningScenario.preset)
        let titles = Set(scenarios.map(\.title))

        XCTAssertTrue(titles.contains("Terse neutral text"))
        XCTAssertTrue(titles.contains("High emotion short text"))
        XCTAssertTrue(titles.contains("Photo with real subject"))
        XCTAssertTrue(titles.contains("Ambient context only"))
        XCTAssertTrue(titles.contains("Dense unrelated history"))
        XCTAssertTrue(titles.contains("Recurring career history"))
        XCTAssertTrue(scenarios.contains { $0.captureSource == .audio })
        XCTAssertTrue(scenarios.contains { $0.artifacts.contains { artifact in
            if case .link = artifact.content { return true }
            return false
        }})
        XCTAssertTrue(scenarios.contains { $0.expectation == .arcExpected })
        XCTAssertTrue(scenarios.contains { $0.expectation == .noArcNoReflection })
        XCTAssertGreaterThanOrEqual(scenarios.count, 14)
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

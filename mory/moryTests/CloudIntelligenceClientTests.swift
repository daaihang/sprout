import Foundation
import XCTest
@testable import mory

@MainActor
final class CloudIntelligenceClientTests: XCTestCase {
    func testAPIClientSendsV6CloudIntelligenceRequests() async throws {
        CloudIntelligenceURLProtocol.responseHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body: String
            switch request.url?.path {
            case "/api/intelligence/refine-transcript":
                body = """
                {
                  "schema_version": 1,
                  "refined_transcript": "今天和妈妈看电影，很开心。",
                  "suggested_title": "电影夜晚",
                  "edits": [{"kind":"punctuation","summary":"Added punctuation"}],
                  "meta": {"provider":"mock","model":"mock-v6-transcript-v1","usage":{"input_tokens":12,"output_tokens":8},"request_id":"req-test"}
                }
                """
            case "/api/intelligence/suggest-questions":
                body = """
                {
                  "schema_version": 1,
                  "questions": [{"kind":"entityRelationship","prompt":"Who is Alex to you?","reason":"Alex appeared repeatedly.","candidate_answers":["friend","coworker"],"confidence":0.72,"sensitivity":"normal"}],
                  "meta": {"provider":"mock","model":"mock-v6-question-v1","usage":{"input_tokens":12,"output_tokens":8},"request_id":"req-test"}
                }
                """
            case "/api/intelligence/suggest-chapters":
                body = """
                {
                  "schema_version": 1,
                  "chapter_candidates": [{"title":"Career Transition","summary":"A work chapter is forming.","evidence_record_ids":["record-1"],"confidence":0.7,"requires_confirmation":true}],
                  "meta": {"provider":"mock","model":"mock-v6-chapter-v1","usage":{"input_tokens":12,"output_tokens":8},"request_id":"req-test"}
                }
                """
            case "/api/intelligence/analyze-photo":
                body = """
                {
                  "schema_version": 1,
                  "semantic_summary": "Photo context: receipt, restaurant",
                  "suggested_title": "Dinner receipt",
                  "tags": ["photo","restaurant"],
                  "objects": ["receipt"],
                  "text_highlights": ["Table 4"],
                  "safety": "normal",
                  "confidence": 0.62,
                  "meta": {"provider":"mock","model":"mock-v6-photo-v1","usage":{"input_tokens":12,"output_tokens":8},"request_id":"req-test"}
                }
                """
            case "/api/intelligence/suggest-notification-intent":
                body = """
                {
                  "schema_version": 1,
                  "intent": {"kind":"dailyQuestion","privacy_level":"generic","title":"Mory","body":"A question is ready for today.","deep_link":"mory://questions"},
                  "meta": {"provider":"mock","model":"mock-v6-notification-v1","usage":{"input_tokens":12,"output_tokens":8},"request_id":"req-test"}
                }
                """
            case "/api/analyze/v7":
                body = """
                {
                  "analysis": {
                    "tags": ["journal"],
                    "emotion": {"label":"neutral","confidence":0.5},
                    "entities": [],
                    "candidate_edges": [],
                    "insight": "Thin evidence.",
                    "summary": "Thin evidence.",
                    "retrieval_terms": [],
                    "follow_up": null
                  },
                  "affect_proposals": [],
                  "graph_delta_proposals": [],
                  "profile_update_proposals": [],
                  "merge_split_candidates": [],
                  "arc_candidates": [],
                  "reflection_candidates": [],
                  "question_candidates": [],
                  "quality": {"confidence":0.42,"uncertainty_reasons":["thin_context"],"needs_user_check":["tone"]},
                  "meta": {"provider":"mock","model":"mock-v7-analyze-v1","usage":{"input_tokens":18,"output_tokens":9},"request_id":"req-test"}
                }
                """
            default:
                XCTFail("Unexpected path \(request.url?.path ?? "<nil>")")
                body = #"{"error":"unexpected path"}"#
            }

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json", "X-Request-ID": "req-test"]
            )!
            return (response, Data(body.utf8))
        }
        defer { CloudIntelligenceURLProtocol.responseHandler = nil }

        let client = makeClient()
        let transcript = try await client.refineTranscript(
            payload: .init(rawTranscript: "今天 和 妈妈 看 电影 很 开心"),
            bearerToken: "token"
        )
        XCTAssertEqual(transcript.refinedTranscript, "今天和妈妈看电影，很开心。")
        XCTAssertEqual(transcript.meta?.provider, "mock")

        let questions = try await client.suggestQuestions(
            payload: .init(
                target: .init(type: "entity", id: "person-1", kind: "person"),
                evidence: [.init(recordID: "record-1", artifactID: nil, snippet: "Alex joined dinner again.", createdAt: nil)],
                knownProfile: .init(displayName: "Alex", aliases: [], relationshipToUser: nil),
                userPreferences: .init(allowSensitiveQuestions: false, questionTone: "evidence_based")
            ),
            bearerToken: "token"
        )
        XCTAssertEqual(questions.questions.first?.kind, "entityRelationship")

        let chapters = try await client.suggestChapters(
            payload: .init(
                timeWindow: .init(start: "2026-05-01T00:00:00Z", end: "2026-05-18T23:59:59Z"),
                signals: [.init(kind: "theme", label: "career transition", recordCount: 7, salience: 0.74)],
                evidenceSnippets: [.init(recordID: "record-1", artifactID: nil, snippet: "I updated my resume again.", createdAt: nil)]
            ),
            bearerToken: "token"
        )
        XCTAssertTrue(chapters.chapterCandidates.first?.requiresConfirmation == true)

        let photo = try await client.analyzePhotoSemantics(
            payload: .init(localLabels: ["receipt"], ocrText: "Table 4", metadata: nil),
            bearerToken: "token"
        )
        XCTAssertEqual(photo.tags.first, "photo")

        let notification = try await client.suggestNotificationIntent(
            payload: .init(
                trigger: "dailyQuestion",
                recentEvidence: [],
                question: .init(kind: "dailyReflection", prompt: "What should Mory remember?", reason: "Daily cadence.", candidateAnswers: [], confidence: 0.7, sensitivity: "normal"),
                preferences: .init(maxPerDay: 2, quietHoursStart: nil, quietHoursEnd: nil, richPreviewsEnabled: false)
            ),
            bearerToken: "token"
        )
        XCTAssertEqual(notification.intent.title, "Mory")

        let v7 = try await client.analyzeRecordsV7(
            payload: .init(
                clientRequestID: "client-v7-test",
                recordShell: .init(
                    id: "record-v7",
                    createdAt: "2026-05-23T00:00:00Z",
                    updatedAt: "2026-05-23T00:00:00Z",
                    rawText: "A thin memory.",
                    captureSource: "composer",
                    userMood: nil,
                    userIntensity: nil,
                    inputContext: nil
                ),
                artifacts: [],
                knownEntities: [],
                moodEvidence: [],
                contextPack: .init(
                    packID: "pack-v7",
                    targetRecordID: "record-v7",
                    selfBrief: nil,
                    knownProfiles: [],
                    relatedMemories: [],
                    relatedArcs: [],
                    priorReflections: [],
                    correctionSignals: [],
                    affectHistory: [],
                    privacyDecisions: [],
                    budgetReport: .init(
                        maxProfiles: 8,
                        maxRelatedMemories: 12,
                        maxArcs: 6,
                        maxReflections: 6,
                        maxCorrections: 10,
                        maxAffectHistory: 8,
                        selectedProfiles: 0,
                        selectedRelatedMemories: 0,
                        selectedArcs: 0,
                        selectedReflections: 0,
                        selectedCorrections: 0,
                        selectedAffectHistory: 0,
                        droppedByBudget: 0,
                        droppedByPrivacy: 0
                    ),
                    retrievalReport: .init(
                        semanticSearchStatus: "disabled",
                        retrievalSources: [],
                        candidateMemoryCount: 0,
                        fallbackReason: "test"
                    ),
                    builtAt: "2026-05-23T00:00:00Z"
                ),
                clientCapabilities: .moryV7Default,
                debugOptions: nil
            ),
            bearerToken: "token"
        )
        XCTAssertEqual(v7.meta?.model, "mock-v7-analyze-v1")
        XCTAssertEqual(v7.quality.uncertaintyReasons, ["thin_context"])
    }

    private func makeClient() -> MoryAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CloudIntelligenceURLProtocol.self]
        return MoryAPIClient(
            configuration: MoryAPIConfiguration(baseURL: URL(string: "https://cloud.test")!),
            session: URLSession(configuration: configuration)
        )
    }
}

private final class CloudIntelligenceURLProtocol: URLProtocol {
    static var responseHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseHandler = Self.responseHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try responseHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

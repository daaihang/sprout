import XCTest
@testable import mory

@MainActor
final class VoiceTranscriptRefinementServiceTests: XCTestCase {
    func testRefinesTranscriptWhenCloudVoicePreferenceIsEnabled() async throws {
        let cloud = MockVoiceRefinementCloudService(
            response: MoryAPIClient.TranscriptRefinementResponse(
                schemaVersion: 1,
                refinedTranscript: "今天和妈妈看电影，很开心。",
                suggestedTitle: "电影夜晚",
                edits: [MoryAPIClient.TranscriptEdit(kind: "punctuation", summary: "Added punctuation")],
                meta: MoryAPIClient.CloudIntelligenceMeta(
                    provider: "mock",
                    model: "mock-v6-transcript-v1",
                    usage: nil,
                    requestID: "req-voice",
                    promptVersion: "prompt-v1"
                )
            )
        )
        let service = VoiceTranscriptRefinementService(cloudIntelligenceService: cloud)

        let result = try await service.refine(
            rawTranscript: "今天 和 妈妈 看 电影 很 开心",
            localeIdentifier: "zh-Hans",
            preferences: .defaults
        )

        XCTAssertEqual(result?.transcript, "今天和妈妈看电影，很开心。")
        XCTAssertEqual(result?.suggestedTitle, "电影夜晚")
        XCTAssertEqual(result?.provider, "mock")
        XCTAssertEqual(result?.requestID, "req-voice")

        let payloads = await cloud.refinePayloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payloads.first?.rawTranscript, "今天 和 妈妈 看 电影 很 开心")
        XCTAssertEqual(payloads.first?.locale, "zh-Hans")
    }

    func testSkipsTranscriptRefinementWhenCloudOrVoicePreferenceIsDisabled() async throws {
        let cloud = MockVoiceRefinementCloudService()
        let service = VoiceTranscriptRefinementService(cloudIntelligenceService: cloud)

        var preferences = IntelligencePreferences.defaults
        preferences.cloudIntelligenceEnabled = false
        let cloudDisabledResult = try await service.refine(rawTranscript: "hello", localeIdentifier: "en-US", preferences: preferences)
        XCTAssertNil(cloudDisabledResult)

        preferences.cloudIntelligenceEnabled = true
        preferences.voiceRefinementEnabled = false
        let voiceDisabledResult = try await service.refine(rawTranscript: "hello", localeIdentifier: "en-US", preferences: preferences)
        XCTAssertNil(voiceDisabledResult)

        let payloads = await cloud.refinePayloads()
        XCTAssertTrue(payloads.isEmpty)
    }

    func testPropagatesCloudFailureSoCallerCanFallbackToRawTranscript() async {
        let cloud = MockVoiceRefinementCloudService(error: VoiceRefinementTestError.offline)
        let service = VoiceTranscriptRefinementService(cloudIntelligenceService: cloud)

        do {
            _ = try await service.refine(rawTranscript: "hello", localeIdentifier: "en-US", preferences: .defaults)
            XCTFail("Expected cloud refinement failure")
        } catch VoiceRefinementTestError.offline {
            let payloads = await cloud.refinePayloads()
            XCTAssertEqual(payloads.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private enum VoiceRefinementTestError: Error {
    case offline
}

private actor MockVoiceRefinementCloudService: CloudIntelligenceServing {
    private var response: MoryAPIClient.TranscriptRefinementResponse
    private var error: Error?
    private var payloads: [MoryAPIClient.TranscriptRefinementPayload] = []

    init(
        response: MoryAPIClient.TranscriptRefinementResponse = MoryAPIClient.TranscriptRefinementResponse(
            schemaVersion: 1,
            refinedTranscript: "Refined transcript.",
            suggestedTitle: "Refined title",
            edits: [],
            meta: nil
        ),
        error: Error? = nil
    ) {
        self.response = response
        self.error = error
    }

    func refinePayloads() -> [MoryAPIClient.TranscriptRefinementPayload] {
        payloads
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        payloads.append(payload)
        if let error {
            throw error
        }
        return response
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        throw VoiceRefinementTestError.offline
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        throw VoiceRefinementTestError.offline
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        throw VoiceRefinementTestError.offline
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        throw VoiceRefinementTestError.offline
    }
}

import Foundation

struct VoiceTranscriptRefinement: Equatable, Sendable {
    var transcript: String
    var suggestedTitle: String?
    var provider: String?
    var requestID: String?
}

struct VoiceTranscriptRefinementService: Sendable {
    private let cloudIntelligenceService: any CloudIntelligenceServing

    init(cloudIntelligenceService: any CloudIntelligenceServing) {
        self.cloudIntelligenceService = cloudIntelligenceService
    }

    func refine(
        rawTranscript: String,
        localeIdentifier: String?,
        preferences: IntelligencePreferences,
        recordID: String? = nil,
        audioArtifactID: String? = nil
    ) async throws -> VoiceTranscriptRefinement? {
        guard preferences.cloudIntelligenceEnabled, preferences.voiceRefinementEnabled else {
            return nil
        }
        guard let transcript = rawTranscript.trimmedOrNil else {
            return nil
        }

        let response = try await cloudIntelligenceService.refineTranscript(
            MoryAPIClient.TranscriptRefinementPayload(
                locale: localeIdentifier,
                recordID: recordID,
                audioArtifactID: audioArtifactID,
                rawTranscript: transcript,
                style: "clean_spoken_memory",
                allowTitle: true
            )
        )
        guard let refined = response.refinedTranscript.trimmedOrNil else {
            return nil
        }

        return VoiceTranscriptRefinement(
            transcript: refined,
            suggestedTitle: response.suggestedTitle?.trimmedOrNil,
            provider: response.meta?.provider,
            requestID: response.meta?.requestID
        )
    }
}

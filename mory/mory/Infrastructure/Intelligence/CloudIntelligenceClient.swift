import Foundation
import OSLog

private let log = Logger(subsystem: "com.mory", category: "intelligence")

protocol CloudIntelligenceServing: Sendable {
    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope
    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse
    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse
    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse
    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse
    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse
}

enum CloudIntelligenceContractError: LocalizedError {
    case analyzeV7Unavailable

    var errorDescription: String? {
        switch self {
        case .analyzeV7Unavailable:
            return "Analyze v7 is not implemented by this cloud intelligence service."
        }
    }
}

extension CloudIntelligenceServing {
    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        throw CloudIntelligenceContractError.analyzeV7Unavailable
    }
}

protocol CloudIntelligenceDebugging: Sendable {
    func latestCloudDebugError() async -> MoryAPIClient.DebugErrorSnapshot?
    func latestCloudDebugRequestID() async -> String?
}

struct RemoteCloudIntelligenceClient: CloudIntelligenceServing {
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider

    init(apiClient: MoryAPIClient, tokenProvider: MoryAuthTokenProvider) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    func analyzeV7(_ payload: AnalyzeV7RequestPayload) async throws -> AnalyzeV7ResponseEnvelope {
        try await send { token in
            try await apiClient.analyzeRecordsV7(payload: payload, bearerToken: token)
        }
    }

    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse {
        try await send { token in
            try await apiClient.refineTranscript(payload: payload, bearerToken: token)
        }
    }

    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse {
        try await send { token in
            try await apiClient.suggestQuestions(payload: payload, bearerToken: token)
        }
    }

    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse {
        try await send { token in
            try await apiClient.suggestChapters(payload: payload, bearerToken: token)
        }
    }

    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse {
        try await send { token in
            try await apiClient.analyzePhotoSemantics(payload: payload, bearerToken: token)
        }
    }

    func runProviderEval() async throws -> MoryAPIClient.CloudIntelligenceEvalResponse {
        try await send { token in
            try await apiClient.runCloudIntelligenceEval(bearerToken: token)
        }
    }

    private func send<Response: Sendable>(
        _ request: (String) async throws -> Response
    ) async throws -> Response {
        do {
            let token = try await tokenProvider.accessToken()
            return try await request(token)
        } catch MoryAPIClient.APIError.unauthorized {
            // Token was rejected by the server. Invalidate the cached token and retry once.
            // If multiple concurrent requests fail with 401 simultaneously, they each call
            // invalidate() (idempotent) then accessToken(). The tokenProvider is responsible
            // for deduplicating concurrent refresh attempts at its own actor boundary.
            log.warning("CloudIntelligence: 401 received — invalidating token and retrying once")
            await tokenProvider.invalidate()
            let freshToken = try await tokenProvider.accessToken()
            return try await request(freshToken)
        }
    }
}

extension RemoteCloudIntelligenceClient: CloudIntelligenceDebugging {
    func latestCloudDebugError() async -> MoryAPIClient.DebugErrorSnapshot? {
        await apiClient.latestDebugError()
    }

    func latestCloudDebugRequestID() async -> String? {
        await apiClient.latestDebugRequestID()
    }
}

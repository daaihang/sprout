import Foundation

protocol CloudIntelligenceServing: Sendable {
    func refineTranscript(_ payload: MoryAPIClient.TranscriptRefinementPayload) async throws -> MoryAPIClient.TranscriptRefinementResponse
    func suggestQuestions(_ payload: MoryAPIClient.QuestionSuggestionPayload) async throws -> MoryAPIClient.QuestionSuggestionResponse
    func suggestChapters(_ payload: MoryAPIClient.ChapterSuggestionPayload) async throws -> MoryAPIClient.ChapterSuggestionResponse
    func analyzePhotoSemantics(_ payload: MoryAPIClient.PhotoSemanticAnalysisPayload) async throws -> MoryAPIClient.PhotoSemanticAnalysisResponse
    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse
}

struct RemoteCloudIntelligenceClient: CloudIntelligenceServing {
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider

    init(apiClient: MoryAPIClient, tokenProvider: MoryAuthTokenProvider) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
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

    func suggestNotificationIntent(_ payload: MoryAPIClient.NotificationIntentSuggestionPayload) async throws -> MoryAPIClient.NotificationIntentSuggestionResponse {
        try await send { token in
            try await apiClient.suggestNotificationIntent(payload: payload, bearerToken: token)
        }
    }

    private func send<Response: Sendable>(
        _ request: (String) async throws -> Response
    ) async throws -> Response {
        do {
            let token = try await tokenProvider.accessToken()
            return try await request(token)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            return try await request(token)
        }
    }
}

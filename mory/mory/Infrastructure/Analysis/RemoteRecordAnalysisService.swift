import Foundation

actor MoryAuthTokenProvider {
    private let apiClient: MoryAPIClient
    private var cachedToken: String?

    init(apiClient: MoryAPIClient) {
        self.apiClient = apiClient
    }

    func accessToken() async throws -> String {
        if let cachedToken {
            return cachedToken
        }

        let auth = try await apiClient.authenticate()
        cachedToken = auth.accessToken
        return auth.accessToken
    }

    func invalidate() {
        cachedToken = nil
    }
}

struct RemoteRecordAnalysisService: RecordAnalysisServing {
    private let requestBuilder = AnalyzeRequestBuilder()
    private let responseMapper = AnalyzeResponseMapper()
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider

    init(
        apiClient: MoryAPIClient,
        tokenProvider: MoryAuthTokenProvider
    ) {
        self.apiClient = apiClient
        self.tokenProvider = tokenProvider
    }

    func analyze(
        record: RecordShell,
        artifacts: [Artifact],
        knownEntities: [EntityReference] = []
    ) async throws -> RecordAnalysisSnapshot {
        let request = requestBuilder.build(
            record: record,
            artifacts: artifacts,
            knownEntities: knownEntities,
            analysisReason: "capture_ingest"
        )

        do {
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        }
    }
}

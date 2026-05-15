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
    private actor DebugTraceStore {
        private var latest: DebugPipelineTraceSnapshot?

        func set(_ value: DebugPipelineTraceSnapshot?) {
            latest = value
        }

        func get() -> DebugPipelineTraceSnapshot? {
            latest
        }
    }

    private let requestBuilder = AnalyzeRequestBuilder()
    private let responseMapper = AnalyzeResponseMapper()
    private let apiClient: MoryAPIClient
    private let tokenProvider: MoryAuthTokenProvider
    private let debugTraceStore = DebugTraceStore()

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
        let requestBody = String(data: (try? JSONEncoder().encode(request)) ?? Data(), encoding: .utf8)

        do {
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            let responseBody = String(data: (try? JSONEncoder().encode(response)) ?? Data(), encoding: .utf8)
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: nil,
                    failedStage: nil
                )
            )
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        } catch MoryAPIClient.APIError.unauthorized {
            await tokenProvider.invalidate()
            let token = try await tokenProvider.accessToken()
            let response = try await apiClient.analyzeRecords(payload: request, bearerToken: token)
            let responseBody = String(data: (try? JSONEncoder().encode(response)) ?? Data(), encoding: .utf8)
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestBody: requestBody,
                    responseBody: responseBody,
                    rawErrorBody: nil,
                    statusCode: nil,
                    failedStage: nil
                )
            )
            return responseMapper.map(recordID: record.id, response: response, createdAt: record.updatedAt)
        } catch {
            let apiTrace = apiClient.latestDebugError()
            await debugTraceStore.set(
                DebugPipelineTraceSnapshot(
                    requestBody: requestBody,
                    responseBody: apiTrace?.responseBody,
                    rawErrorBody: apiTrace?.rawErrorBody,
                    statusCode: apiTrace?.statusCode,
                    failedStage: apiTrace?.failedStage
                )
            )
            throw error
        }
    }

    func latestDebugTrace() async -> DebugPipelineTraceSnapshot? {
        await debugTraceStore.get()
    }
}

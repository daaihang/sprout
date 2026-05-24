import Foundation

extension MoryAPIClient {
    struct CloudIntelligenceUsage: Codable, Sendable, Equatable {
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    struct CloudIntelligenceMeta: Codable, Sendable, Equatable {
        let provider: String
        let model: String
        let usage: CloudIntelligenceUsage?
        let requestID: String?
        let promptVersion: String?

        enum CodingKeys: String, CodingKey {
            case provider
            case model
            case usage
            case requestID = "request_id"
            case promptVersion = "prompt_version"
        }
    }

    struct CloudIntelligenceEvalCase: Decodable, Sendable, Equatable {
        let operation: String
        let success: Bool
        let provider: String?
        let model: String?
        let error: String?
        let errorClass: String?
        let retryable: Bool?

        enum CodingKeys: String, CodingKey {
            case operation
            case success
            case provider
            case model
            case error
            case errorClass = "error_class"
            case retryable
        }
    }

    struct CloudIntelligenceEvalResponse: Decodable, Sendable, Equatable {
        let promptVersion: String
        let requestID: String?
        let cases: [CloudIntelligenceEvalCase]

        enum CodingKeys: String, CodingKey {
            case promptVersion = "prompt_version"
            case requestID = "request_id"
            case cases
        }
    }

    func runCloudIntelligenceEval(
        bearerToken: String
    ) async throws -> CloudIntelligenceEvalResponse {
        struct EmptyPayload: Encodable {}
        return try await postAuthenticated(
            path: "/api/intelligence/eval",
            payload: EmptyPayload(),
            bearerToken: bearerToken,
            requestIDPrefix: "v6-provider-eval",
            failedStage: "v6_provider_eval",
            responseType: CloudIntelligenceEvalResponse.self
        )
    }

    func fetchServerMetricsText() async throws -> String {
        var request = URLRequest(url: configuration.url(for: "/metrics"))
        let requestID = makeDebugRequestID(prefix: "server-metrics")
        request.httpMethod = "GET"
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8)
                throw APIError.server(statusCode: httpResponse.statusCode, message: body ?? "metrics request failed", body: body)
            }
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            throw normalize(error: error, failedStage: "server_metrics")
        }
    }

    func latestDebugError() async -> DebugErrorSnapshot? {
        await debugTraceBox.current()
    }

    func latestDebugRequestID() async -> String? {
        await debugTraceBox.currentRequestID()
    }

}

import Foundation

struct MoryAuthResponse: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let id: String
        let tier: String
    }

    let accessToken: String
    let refreshToken: String?
    let expiresAt: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct MoryAPIClient: Sendable {
    struct ReflectionPayload: Encodable, Sendable {
        var recordShell: AnalyzeRequestPayload.RecordShellPayload
        var artifacts: [AnalyzeRequestPayload.ArtifactPayload]
        var linkedArcID: String?
        var knownEntities: [AnalyzeRequestPayload.KnownEntityPayload]
        var prompt: String?

        enum CodingKeys: String, CodingKey {
            case recordShell = "record_shell"
            case artifacts
            case linkedArcID = "linked_arc_id"
            case knownEntities = "known_entities"
            case prompt
        }
    }

    struct ReflectionResponse: Decodable, Sendable {
        let title: String
        let body: String
        let evidenceSummary: String
        let confidence: Double
        let sourceRecordIDs: [String]

        enum CodingKeys: String, CodingKey {
            case title
            case body
            case evidenceSummary = "evidence_summary"
            case confidence
            case sourceRecordIDs = "source_record_ids"
        }
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case unauthorized
        case server(statusCode: Int, message: String, body: String?)
        case network(String)
        case decoding(String, body: String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case .unauthorized:
                return "Analysis authorization failed."
            case let .server(statusCode, message, _):
                return "Server error \(statusCode): \(message)"
            case let .network(message):
                return "Network error: \(message)"
            case let .decoding(message, _):
                return "Response decoding failed: \(message)"
            }
        }
    }

    struct DebugErrorSnapshot: Sendable {
        let statusCode: Int?
        let responseBody: String?
        let rawErrorBody: String?
        let failedStage: String?
        let errorDescription: String
    }

    struct ErrorEnvelope: Decodable {
        let error: String?
    }

    private actor DebugTraceStore {
        var latest: DebugErrorSnapshot?

        func update(_ snapshot: DebugErrorSnapshot?) {
            latest = snapshot
        }

        func current() -> DebugErrorSnapshot? {
            latest
        }
    }

    private let configuration: MoryAPIConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let debugTraceBox = DebugTraceStore()

    init(
        configuration: MoryAPIConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    var baseURL: URL {
        configuration.baseURL
    }

    func authenticate(identityToken: String) async throws -> MoryAuthResponse {
        struct Payload: Encodable {
            let identityToken: String

            enum CodingKeys: String, CodingKey {
                case identityToken = "identity_token"
            }
        }

        var request = URLRequest(url: configuration.url(for: configuration.authPath))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(Payload(identityToken: identityToken))

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: MoryAuthResponse.self, failedStage: "auth_apple")
        } catch {
            throw normalize(error: error, failedStage: "auth_apple")
        }
    }

    func analyzeRecords(
        payload: AnalyzeRequestPayload,
        bearerToken: String
    ) async throws -> AnalyzeResponseEnvelope {
        var request = URLRequest(url: configuration.url(for: configuration.analysisPath))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: AnalyzeResponseEnvelope.self, failedStage: "analysis")
        } catch {
            throw normalize(error: error, failedStage: "analysis")
        }
    }

    func generateReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_generate")
        } catch {
            throw normalize(error: error, failedStage: "reflection_generate")
        }
    }

    func replayReflection(
        payload: ReflectionPayload,
        bearerToken: String
    ) async throws -> ReflectionResponse {
        var request = URLRequest(url: configuration.url(for: "/api/reflections/replay"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: ReflectionResponse.self, failedStage: "reflection_replay")
        } catch {
            throw normalize(error: error, failedStage: "reflection_replay")
        }
    }

    func latestDebugError() async -> DebugErrorSnapshot? {
        await debugTraceBox.current()
    }

    func refreshToken(refreshToken: String) async throws -> MoryAuthResponse {
        var request = URLRequest(url: configuration.url(for: "/api/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(refreshToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            return try decodeResponse(data: data, response: response, as: MoryAuthResponse.self, failedStage: "auth_refresh")
        } catch {
            throw normalize(error: error, failedStage: "auth_refresh")
        }
    }

    private func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        as type: T.Type,
        failedStage: String = "analysis"
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                let body = String(data: data, encoding: .utf8)
                let apiError = APIError.decoding(error.localizedDescription, body: body)
                setDebugError(statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: error.localizedDescription)
                throw apiError
            }
        case 401:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? "unauthorized"
            setDebugError(statusCode: 401, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            setDebugError(statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.server(statusCode: httpResponse.statusCode, message: message, body: body)
        }
    }

    private func normalize(error: Error, failedStage: String) -> Error {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse:
                setDebugError(statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: apiError.localizedDescription)
            case .unauthorized:
                break
            case .server:
                break
            case let .network(message):
                setDebugError(statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: message)
            case .decoding:
                break
            }
            return apiError
        }

        setDebugError(
            statusCode: nil,
            responseBody: nil,
            rawErrorBody: nil,
            failedStage: failedStage,
            errorDescription: error.localizedDescription
        )
        return APIError.network(error.localizedDescription)
    }

    private func setDebugError(
        statusCode: Int?,
        responseBody: String?,
        rawErrorBody: String?,
        failedStage: String,
        errorDescription: String
    ) {
        let snapshot = DebugErrorSnapshot(
            statusCode: statusCode,
            responseBody: responseBody,
            rawErrorBody: rawErrorBody,
            failedStage: failedStage,
            errorDescription: errorDescription
        )
        Task { await debugTraceBox.update(snapshot) }
    }
}

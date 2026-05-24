import Foundation

struct MoryAPIClient: Sendable {
    static let backgroundSessionID = "dev.mory.api.background"

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
        let requestID: String?
        let statusCode: Int?
        let responseBody: String?
        let rawErrorBody: String?
        let failedStage: String?
        let errorDescription: String
    }

    struct ErrorEnvelope: Decodable {
        let error: String?
    }

    actor DebugTraceStore {
        var latest: DebugErrorSnapshot?
        var latestRequestID: String?

        func update(_ snapshot: DebugErrorSnapshot?) {
            latest = snapshot
            latestRequestID = snapshot?.requestID
        }

        func current() -> DebugErrorSnapshot? {
            latest
        }

        func setRequestID(_ requestID: String?) {
            latestRequestID = requestID
        }

        func currentRequestID() -> String? {
            latestRequestID
        }
    }

    let configuration: MoryAPIConfiguration
    let session: URLSession
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let debugTraceBox = DebugTraceStore()

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
    func postAuthenticated<Payload: Encodable, Response: Decodable>(
        path: String,
        payload: Payload,
        bearerToken: String,
        requestIDPrefix: String,
        failedStage: String,
        responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: configuration.url(for: path))
        let requestID = makeDebugRequestID(prefix: requestIDPrefix)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.httpBody = try encoder.encode(payload)

        do {
            let (data, response) = try await session.data(for: request)
            let decoded = try decodeResponse(data: data, response: response, as: responseType, failedStage: failedStage, requestID: requestID)
            await debugTraceBox.setRequestID(responseRequestID(response) ?? requestID)
            return decoded
        } catch {
            throw normalize(error: error, failedStage: failedStage)
        }
    }

    func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        as type: T.Type,
        failedStage: String = "analysis",
        requestID: String? = nil
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
                setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: error.localizedDescription)
                throw apiError
            }
        case 401:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? "unauthorized"
            setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: 401, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            setDebugError(requestID: responseRequestID(response) ?? requestID, statusCode: httpResponse.statusCode, responseBody: body, rawErrorBody: body, failedStage: failedStage, errorDescription: message)
            throw APIError.server(statusCode: httpResponse.statusCode, message: message, body: body)
        }
    }

    func normalize(error: Error, failedStage: String) -> Error {
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidResponse:
                setDebugError(requestID: nil, statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: apiError.localizedDescription)
            case .unauthorized:
                break
            case .server:
                break
            case let .network(message):
                setDebugError(requestID: nil, statusCode: nil, responseBody: nil, rawErrorBody: nil, failedStage: failedStage, errorDescription: message)
            case .decoding:
                break
            }
            return apiError
        }

        setDebugError(
            requestID: nil,
            statusCode: nil,
            responseBody: nil,
            rawErrorBody: nil,
            failedStage: failedStage,
            errorDescription: error.localizedDescription
        )
        return APIError.network(error.localizedDescription)
    }

    func setDebugError(
        requestID: String?,
        statusCode: Int?,
        responseBody: String?,
        rawErrorBody: String?,
        failedStage: String,
        errorDescription: String
    ) {
        // Truncate body in all builds to prevent accidental credential exposure via memory/crash dumps.
        // In non-debug builds, body is fully redacted since it may contain user data or auth tokens.
        #if DEBUG
        let safeBody = responseBody.map { String($0.prefix(2000)) }
        let safeRawBody = rawErrorBody.map { String($0.prefix(500)) }
        #else
        let safeBody = responseBody.map { _ in "[body redacted]" }
        let safeRawBody = rawErrorBody.map { _ in "[body redacted]" }
        #endif
        let snapshot = DebugErrorSnapshot(
            requestID: requestID,
            statusCode: statusCode,
            responseBody: safeBody,
            rawErrorBody: safeRawBody,
            failedStage: failedStage,
            errorDescription: errorDescription
        )
        Task { await debugTraceBox.update(snapshot) }
    }

    func makeDebugRequestID(prefix: String) -> String {
        "mory-\(prefix)-\(UUID().uuidString)"
    }

    func responseRequestID(_ response: URLResponse) -> String? {
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Request-ID")
    }
}

import Foundation

struct MoryAuthResponse: Decodable, Sendable {
    struct User: Decodable, Sendable {
        let id: String
        let tier: String
    }

    let accessToken: String
    let expiresAt: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct MoryAPIClient: Sendable {
    enum APIError: LocalizedError {
        case invalidResponse
        case unauthorized
        case server(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid server response."
            case .unauthorized:
                return "Analysis authorization failed."
            case let .server(statusCode, message):
                return "Server error \(statusCode): \(message)"
            }
        }
    }

    struct ErrorEnvelope: Decodable {
        let error: String?
    }

    private let configuration: MoryAPIConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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

    func authenticate() async throws -> MoryAuthResponse {
        struct Payload: Encodable {
            let identityToken: String

            enum CodingKeys: String, CodingKey {
                case identityToken = "identity_token"
            }
        }

        var request = URLRequest(url: configuration.url(for: configuration.authPath))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(Payload(identityToken: configuration.devAuthIdentityToken))

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response, as: MoryAuthResponse.self)
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

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response, as: AnalyzeResponseEnvelope.self)
    }

    private func decodeResponse<T: Decodable>(
        data: Data,
        response: URLResponse,
        as type: T.Type
    ) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        default:
            let message = (try? decoder.decode(ErrorEnvelope.self, from: data).error) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }
    }
}

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

extension MoryAPIClient {
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

}

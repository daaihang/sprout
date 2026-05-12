import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

@Observable
@MainActor
final class AuthSessionManager {
    struct RequestRecord: Identifiable, Equatable {
        let id = UUID()
        let kind: String
        let method: String
        let url: String
        let requestHeaders: [String: String]
        let requestBody: String?
        let startedAt: Date
        var completedAt: Date?
        var statusCode: Int?
        var responseHeaders: [String: String]
        var responseBody: String?
        var errorDescription: String?

        var durationText: String {
            guard let completedAt else { return "-" }
            return String(format: "%.2fs", completedAt.timeIntervalSince(startedAt))
        }
    }

    struct HealthCheckResult: Equatable {
        let requestedURL: String
        let checkedAt: Date
        let statusCode: Int?
        let responseBody: String?
        let errorDescription: String?
        let duration: TimeInterval

        var durationText: String {
            String(format: "%.2fs", duration)
        }
    }

    struct Session: Codable, Equatable {
        let accessToken: String
        let expiresAt: Date
        let userID: String
        let tier: String
        let mode: String

        var isExpired: Bool { expiresAt <= Date() }
    }

    struct AppleSignInPayload {
        let identityToken: String
        let rawNonce: String
    }

    private struct AuthResponse: Decodable {
        struct User: Decodable {
            let id: String
            let tier: String
        }

        let accessToken: String
        let expiresAt: Date
        let user: User
        let mode: String

        private enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresAt = "expires_at"
            case user
            case mode
        }
    }

    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(Session)
    }

    var state: State = .loading
    var errorMessage: String? = nil
    var isAuthenticating = false
    var lastAppleIdentityToken: String? = nil
    var lastAppleRawNonce: String? = nil
    var lastAppleHashedNonce: String? = nil
    var lastAuthRequest: RequestRecord? = nil
    var lastRefreshRequest: RequestRecord? = nil
    var lastHealthCheck: HealthCheckResult? = nil

    private let keychain = AuthKeychainStore()
    private let sessionKey = "auth.session"

    init() {
        restoreSession()
    }

    var currentSession: Session? {
        if case let .signedIn(session) = state { return session }
        return nil
    }

    func restoreSession() {
        guard let session = try? keychain.load(sessionKey, as: Session.self), !session.isExpired else {
            try? keychain.delete(sessionKey)
            state = .signedOut
            return
        }
        state = .signedIn(session)
    }

    func signInWithApple(payload: AppleSignInPayload) async {
        isAuthenticating = true
        defer { isAuthenticating = false }
        errorMessage = nil
        lastAppleIdentityToken = payload.identityToken
        lastAppleRawNonce = payload.rawNonce
        lastAppleHashedNonce = AppleNonce.sha256(payload.rawNonce)

        do {
            var request = URLRequest(url: try endpoint("/auth/apple"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "identity_token": payload.identityToken,
                "nonce": payload.rawNonce,
            ])

            let startedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            lastAuthRequest = makeRequestRecord(
                kind: "apple_sign_in",
                request: request,
                startedAt: startedAt,
                response: response,
                data: data,
                error: nil
            )
            try validate(response: response, data: data)
            let decoded = try JSONDecoder.authDecoder.decode(AuthResponse.self, from: data)
            let session = Session(
                accessToken: decoded.accessToken,
                expiresAt: decoded.expiresAt,
                userID: decoded.user.id,
                tier: decoded.user.tier,
                mode: decoded.mode
            )
            try keychain.save(session, for: sessionKey)
            state = .signedIn(session)
        } catch {
            if lastAuthRequest == nil {
                lastAuthRequest = makeRequestRecord(
                    kind: "apple_sign_in",
                    request: (try? makeAuthRequest(path: "/auth/apple", body: [
                        "identity_token": payload.identityToken,
                        "nonce": payload.rawNonce,
                    ])),
                    startedAt: Date(),
                    response: nil,
                    data: nil,
                    error: error
                )
            } else {
                if var record = lastAuthRequest {
                    record.errorDescription = error.localizedDescription
                    record.completedAt = record.completedAt ?? Date()
                    lastAuthRequest = record
                }
            }
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func refreshSessionIfNeeded() async {
        guard let session = currentSession else { return }
        guard session.mode != "development_stub" else { return }
        guard session.expiresAt.timeIntervalSinceNow < 6 * 60 * 60 else { return }
        await refreshSession()
    }

    func refreshSession() async {
        guard let session = currentSession else { return }
        guard session.mode != "development_stub" else { return }

        do {
            var request = URLRequest(url: try endpoint("/auth/refresh"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

            let startedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            lastRefreshRequest = makeRequestRecord(
                kind: "auth_refresh",
                request: request,
                startedAt: startedAt,
                response: response,
                data: data,
                error: nil
            )
            try validate(response: response, data: data)
            let decoded = try JSONDecoder.authDecoder.decode(AuthResponse.self, from: data)
            let refreshed = Session(
                accessToken: decoded.accessToken,
                expiresAt: decoded.expiresAt,
                userID: decoded.user.id,
                tier: decoded.user.tier,
                mode: decoded.mode
            )
            try keychain.save(refreshed, for: sessionKey)
            state = .signedIn(refreshed)
        } catch {
            if lastRefreshRequest == nil {
                lastRefreshRequest = makeRequestRecord(
                    kind: "auth_refresh",
                    request: try? refreshRequest(for: session),
                    startedAt: Date(),
                    response: nil,
                    data: nil,
                    error: error
                )
            } else {
                if var record = lastRefreshRequest {
                    record.errorDescription = error.localizedDescription
                    record.completedAt = record.completedAt ?? Date()
                    lastRefreshRequest = record
                }
            }
            try? keychain.delete(sessionKey)
            errorMessage = error.localizedDescription
            state = .signedOut
        }
    }

    func signOut() {
        try? keychain.delete(sessionKey)
        errorMessage = nil
        state = .signedOut
    }

    func signInForDevelopmentBypass() {
        let session = Session(
            accessToken: "development_stub",
            expiresAt: Date().addingTimeInterval(60 * 60 * 24 * 365),
            userID: "Developer",
            tier: "free",
            mode: "development_stub"
        )
        try? keychain.save(session, for: sessionKey)
        errorMessage = nil
        state = .signedIn(session)
    }

    func runHealthCheck() async {
        let urlString = MoryConfig.apiBaseURL + "/healthz"
        let startedAt = Date()

        guard let url = URL(string: urlString) else {
            lastHealthCheck = HealthCheckResult(
                requestedURL: urlString,
                checkedAt: startedAt,
                statusCode: nil,
                responseBody: nil,
                errorDescription: AuthError.invalidBaseURL.localizedDescription,
                duration: 0
            )
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let completedAt = Date()
            let httpResponse = response as? HTTPURLResponse
            lastHealthCheck = HealthCheckResult(
                requestedURL: urlString,
                checkedAt: completedAt,
                statusCode: httpResponse?.statusCode,
                responseBody: Self.stringBody(from: data),
                errorDescription: nil,
                duration: completedAt.timeIntervalSince(startedAt)
            )
        } catch {
            let completedAt = Date()
            lastHealthCheck = HealthCheckResult(
                requestedURL: urlString,
                checkedAt: completedAt,
                statusCode: nil,
                responseBody: nil,
                errorDescription: error.localizedDescription,
                duration: completedAt.timeIntervalSince(startedAt)
            )
        }
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: MoryConfig.apiBaseURL + path) else {
            throw AuthError.invalidBaseURL
        }
        return url
    }

    private func makeAuthRequest(path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: try endpoint(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func refreshRequest(for session: Session) throws -> URLRequest {
        var request = URLRequest(url: try endpoint("/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func makeRequestRecord(
        kind: String,
        request: URLRequest?,
        startedAt: Date,
        response: URLResponse?,
        data: Data?,
        error: Error?
    ) -> RequestRecord {
        let httpResponse = response as? HTTPURLResponse
        return RequestRecord(
            kind: kind,
            method: request?.httpMethod ?? "POST",
            url: request?.url?.absoluteString ?? MoryConfig.apiBaseURL,
            requestHeaders: request?.allHTTPHeaderFields ?? [:],
            requestBody: Self.stringBody(from: request?.httpBody),
            startedAt: startedAt,
            completedAt: Date(),
            statusCode: httpResponse?.statusCode,
            responseHeaders: httpResponse?.allHeaderFields.reduce(into: [:]) { partial, item in
                partial[String(describing: item.key)] = String(describing: item.value)
            } ?? [:],
            responseBody: Self.stringBody(from: data),
            errorDescription: error?.localizedDescription
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerErrorResponse.self, from: data).error) ?? "Request failed (\(httpResponse.statusCode))"
            throw AuthError.server(message)
        }
    }

    private static func stringBody(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8) ?? data.base64EncodedString()
    }
}

enum AuthError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case missingIdentityToken
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "MORY_API_BASE_URL is not configured."
        case .invalidResponse:
            return "Invalid server response."
        case .missingIdentityToken:
            return "Apple identity token is missing."
        case let .server(message):
            return message
        }
    }
}

struct ServerErrorResponse: Decodable {
    let error: String
}

enum AppleNonce {
    static func random() -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = 32

        while remaining > 0 {
            let bytes: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                precondition(status == errSecSuccess)
                return random
            }

            for byte in bytes {
                if remaining == 0 { break }
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct AuthKeychainStore {
    func save<T: Encodable>(_ value: T, for key: String) throws {
        let data = try JSONEncoder.authEncoder.encode(value)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.speculolabs.sprout.auth",
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)

        var item = query
        item[kSecValueData] = data
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
    }

    func load<T: Decodable>(_ key: String, as type: T.Type) throws -> T? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.speculolabs.sprout.auth",
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        return try JSONDecoder.authDecoder.decode(T.self, from: data)
    }

    func delete(_ key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: "com.speculolabs.sprout.auth",
            kSecAttrAccount: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status)
        }
    }
}

private enum KeychainError: Error {
    case invalidData
    case unhandled(OSStatus)
}

private extension JSONDecoder {
    static var authDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var authEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

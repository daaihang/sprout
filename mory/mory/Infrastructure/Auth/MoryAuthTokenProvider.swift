import Foundation

actor MoryAuthTokenProvider {
    private let apiClient: MoryAPIClient
    private let credentialStore: KeychainCredentialStore
    private var cachedToken: String?
    private var tokenExpiresAt: Date?
    private var didPostSessionExpired = false
    private let refreshMarginSeconds: TimeInterval = 60

    init(apiClient: MoryAPIClient, credentialStore: KeychainCredentialStore) {
        self.apiClient = apiClient
        self.credentialStore = credentialStore
    }

    func accessToken() async throws -> String {
        if let cachedToken, let tokenExpiresAt, tokenExpiresAt > Date().addingTimeInterval(refreshMarginSeconds) {
            return cachedToken
        }

        if let credential = await credentialStore.loadCredential() {
            if credential.isGuest {
                return credential.accessToken
            }

            if !credential.accessToken.isEmpty,
               let expiresAt = credential.expiresAt,
               expiresAt > Date().addingTimeInterval(refreshMarginSeconds) {
                cachedToken = credential.accessToken
                tokenExpiresAt = expiresAt
                return credential.accessToken
            }

            if !credential.refreshToken.isEmpty {
                let auth: MoryAuthResponse
                do {
                    auth = try await apiClient.refreshToken(refreshToken: credential.refreshToken)
                } catch MoryAPIClient.APIError.unauthorized {
                    try? await credentialStore.delete()
                    invalidate()
                    await postSessionExpired(reason: "Refresh token expired.")
                    throw MoryAPIClient.APIError.unauthorized
                } catch {
                    throw error
                }
                let refreshedCredential = AuthCredential(
                    accessToken: auth.accessToken,
                    refreshToken: auth.refreshToken ?? credential.refreshToken,
                    expiresAt: parseExpiresAt(auth.expiresAt),
                    userID: auth.user.id,
                    identityToken: credential.identityToken
                )
                try await credentialStore.saveCredential(refreshedCredential)
                cachedToken = refreshedCredential.accessToken
                tokenExpiresAt = refreshedCredential.expiresAt
                return refreshedCredential.accessToken
            }
        }

        let identityToken: String
        #if DEBUG
        identityToken = (try? await credentialStore.getIdentityToken()) ?? "dev-user"
        #else
        guard let storedIdentityToken = try await credentialStore.getIdentityToken() else {
            await postSessionExpired(reason: "No identity token available.")
            throw AuthTokenError.noIdentityToken
        }
        identityToken = storedIdentityToken
        #endif

        let auth = try await apiClient.authenticate(identityToken: identityToken)
        let credential = AuthCredential(
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken ?? auth.accessToken,
            expiresAt: parseExpiresAt(auth.expiresAt),
            userID: auth.user.id,
            identityToken: identityToken
        )
        try await credentialStore.saveCredential(credential)
        cachedToken = credential.accessToken
        tokenExpiresAt = credential.expiresAt
        return credential.accessToken
    }

    func invalidate() {
        cachedToken = nil
        tokenExpiresAt = nil
    }

    private func postSessionExpired(reason: String) async {
        guard !didPostSessionExpired else { return }
        didPostSessionExpired = true
        await MainActor.run {
            NotificationCenter.default.post(
                name: .moryAuthSessionExpired,
                object: nil,
                userInfo: [MoryAuthSessionExpiredUserInfoKey.reason: reason]
            )
        }
    }

    private func parseExpiresAt(_ expiresAt: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: expiresAt)
            ?? ISO8601DateFormatter().date(from: expiresAt)
    }

    enum AuthTokenError: Error, LocalizedError {
        case noIdentityToken

        var errorDescription: String? {
            switch self {
            case .noIdentityToken:
                return "No identity token available. Please sign in with Apple."
            }
        }
    }
}

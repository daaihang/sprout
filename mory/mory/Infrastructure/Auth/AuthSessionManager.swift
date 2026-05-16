import Foundation
import os

struct AuthDiagnosticsSnapshot: Hashable, Sendable {
    let state: String
    let apiBaseURL: String
    let hasStoredCredential: Bool
    let userID: String?
    let isGuest: Bool
    let hasAccessToken: Bool
    let hasRefreshToken: Bool
    let hasIdentityToken: Bool
    let isExpired: Bool
    let expiresAt: Date?
    let lastEvent: String?
    let lastError: String?
    let lastHTTPStatusCode: Int?
    let lastFailedStage: String?
    let lastResponseBody: String?
    let updatedAt: Date
}

/// Manages the app-wide authentication session.
///
/// On launch, checks Keychain for a persisted credential:
/// - Valid token → authenticated immediately (no login screen)
/// - Expired token → attempts silent refresh via `/auth/refresh`
/// - No token → shows sign-in view
@MainActor
@Observable
final class AuthSessionManager {

    enum State: Sendable, Equatable {
        case loading
        case authenticated
        case unauthenticated
    }

    private(set) var state: State = .loading
    private(set) var lastEvent: String?
    private(set) var lastErrorMessage: String?

    private let credentialStore: KeychainCredentialStore
    private let apiClient: MoryAPIClient
    private let logger = Logger(subsystem: "com.speculolabs.mory", category: "Auth")

    init(credentialStore: KeychainCredentialStore, apiClient: MoryAPIClient) {
        self.credentialStore = credentialStore
        self.apiClient = apiClient
    }

    // MARK: - Session Lifecycle

    /// Called once at app launch to restore session from Keychain.
    func checkSession() async {
        lastEvent = "Checking stored auth session"
        let credential = await credentialStore.loadCredential()

        guard let credential else {
            logger.info("No stored credential — showing sign-in")
            lastEvent = "No stored credential"
            state = .unauthenticated
            return
        }

        if credential.isGuest {
            logger.info("Guest credential found — entering guest mode")
            lastEvent = "Restored guest session"
            lastErrorMessage = nil
            state = .authenticated
            return
        }

        if credential.accessToken.isEmpty {
            logger.info("Local Apple credential found — entering local authenticated mode")
            lastEvent = "Restored local Apple session without server token"
            lastErrorMessage = nil
            state = .authenticated
            return
        }

        if !credential.isExpired {
            logger.info("Valid credential found — user \(credential.userID)")
            lastEvent = "Restored server authenticated session"
            lastErrorMessage = nil
            state = .authenticated
            return
        }

        // Token expired — try refresh
        logger.info("Credential expired — attempting refresh")
        if credential.accessToken.isEmpty {
            // v3 legacy credential without accessToken — re-authenticate
            await reAuthenticateWithIdentityToken(credential)
        } else {
            await refreshExpiredToken(credential)
        }
    }

    /// Called after successful Apple Sign-In.
    @discardableResult
    func didSignIn(identityToken: String, userID: String) async -> Bool {
        let trimmedIdentityToken = identityToken.trimmingCharacters(in: .whitespacesAndNewlines)
        lastEvent = "Apple authorization completed; authenticating with server"
        lastErrorMessage = nil

        do {
            guard !trimmedIdentityToken.isEmpty else {
                try await saveLocalAppleSession(identityToken: nil, userID: userID)
                lastEvent = "Apple sign-in returned no identity token; entered local mode"
                state = .authenticated
                return true
            }

            let authResponse = try await apiClient.authenticate(identityToken: trimmedIdentityToken)
            let credential = AuthCredential(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken ?? authResponse.accessToken,
                expiresAt: parseExpiresAt(authResponse.expiresAt),
                userID: authResponse.user.id,
                identityToken: trimmedIdentityToken
            )
            try await credentialStore.saveCredential(credential)
            logger.info("Sign-in successful — user \(credential.userID)")
            lastEvent = "Server Apple authentication succeeded"
            lastErrorMessage = nil
            state = .authenticated
            return true
        } catch {
            let apiError = await apiClient.latestDebugError()
            let message = apiError?.responseBody?.trimmedOrNil
                ?? apiError?.rawErrorBody?.trimmedOrNil
                ?? apiError?.errorDescription
                ?? error.localizedDescription
            logger.warning("Server Apple authentication failed; entering local mode: \(message)")
            do {
                try await saveLocalAppleSession(
                    identityToken: trimmedIdentityToken.isEmpty ? nil : trimmedIdentityToken,
                    userID: userID
                )
                lastEvent = "Server Apple authentication failed; saved local Apple session"
                lastErrorMessage = message
                state = .authenticated
                return true
            } catch {
                logger.error("Failed to save local Apple credential: \(error.localizedDescription)")
                lastEvent = "Apple sign-in failed"
                lastErrorMessage = error.localizedDescription
                state = .unauthenticated
                return false
            }
        }
    }

    /// Called for guest mode.
    func continueAsGuest() async {
        do {
            try await credentialStore.saveCredential(.guest)
            lastEvent = "Entered guest mode"
            lastErrorMessage = nil
            state = .authenticated
        } catch {
            logger.error("Failed to save guest credential: \(error.localizedDescription)")
            lastEvent = "Entered guest mode without persisted credential"
            lastErrorMessage = error.localizedDescription
            state = .authenticated // still let them in
        }
    }

    /// Called when user explicitly signs out.
    func signOut() async {
        do {
            try await credentialStore.delete()
        } catch {
            logger.error("Failed to clear keychain: \(error.localizedDescription)")
        }
        lastEvent = "Signed out"
        lastErrorMessage = nil
        state = .unauthenticated
    }

    func fetchDiagnostics() async -> AuthDiagnosticsSnapshot {
        let credential = await credentialStore.loadCredential()
        let apiError = await apiClient.latestDebugError()
        return AuthDiagnosticsSnapshot(
            state: state.label,
            apiBaseURL: apiClient.baseURL.absoluteString,
            hasStoredCredential: credential != nil,
            userID: credential?.userID,
            isGuest: credential?.isGuest ?? false,
            hasAccessToken: credential?.accessToken.isEmpty == false,
            hasRefreshToken: credential?.refreshToken.isEmpty == false,
            hasIdentityToken: credential?.identityToken?.isEmpty == false,
            isExpired: credential?.isExpired ?? false,
            expiresAt: credential?.expiresAt,
            lastEvent: lastEvent,
            lastError: lastErrorMessage ?? apiError?.errorDescription,
            lastHTTPStatusCode: apiError?.statusCode,
            lastFailedStage: apiError?.failedStage,
            lastResponseBody: apiError?.responseBody ?? apiError?.rawErrorBody,
            updatedAt: Date.now
        )
    }

    // MARK: - Private

    private func refreshExpiredToken(_ credential: AuthCredential) async {
        do {
            guard !credential.refreshToken.isEmpty else {
                await reAuthenticateWithIdentityToken(credential)
                return
            }
            let refreshed = try await apiClient.refreshToken(refreshToken: credential.refreshToken)
            let newCredential = AuthCredential(
                accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken ?? credential.refreshToken,
                expiresAt: parseExpiresAt(refreshed.expiresAt),
                userID: refreshed.user.id,
                identityToken: credential.identityToken
            )
            try await credentialStore.saveCredential(newCredential)
            logger.info("Token refresh successful")
            lastEvent = "Token refresh succeeded"
            lastErrorMessage = nil
            state = .authenticated
        } catch {
            logger.warning("Token refresh failed: \(error.localizedDescription)")
            lastErrorMessage = error.localizedDescription
            // Try re-auth with identity token if available
            if credential.identityToken != nil {
                await reAuthenticateWithIdentityToken(credential)
            } else {
                await clearAndSignOut()
            }
        }
    }

    private func reAuthenticateWithIdentityToken(_ credential: AuthCredential) async {
        guard let identityToken = credential.identityToken, !identityToken.isEmpty else {
            await clearAndSignOut()
            return
        }

        do {
            let authResponse = try await apiClient.authenticate(identityToken: identityToken)
            let newCredential = AuthCredential(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken ?? authResponse.accessToken,
                expiresAt: parseExpiresAt(authResponse.expiresAt),
                userID: authResponse.user.id,
                identityToken: identityToken
            )
            try await credentialStore.saveCredential(newCredential)
            logger.info("Re-authentication with identity token successful")
            lastEvent = "Server re-authentication succeeded"
            lastErrorMessage = nil
            state = .authenticated
        } catch {
            logger.warning("Re-authentication failed: \(error.localizedDescription)")
            do {
                try await saveLocalAppleSession(identityToken: identityToken, userID: credential.userID)
                lastEvent = "Server re-authentication failed; restored local Apple session"
                lastErrorMessage = error.localizedDescription
                state = .authenticated
            } catch {
                await clearAndSignOut()
            }
        }
    }

    private func saveLocalAppleSession(identityToken: String?, userID: String) async throws {
        let credential = AuthCredential(
            accessToken: "",
            refreshToken: "",
            expiresAt: nil,
            userID: userID,
            identityToken: identityToken
        )
        try await credentialStore.saveCredential(credential)
    }

    private func clearAndSignOut() async {
        do {
            try await credentialStore.delete()
        } catch {
            logger.error("Failed to clear keychain on signout: \(error.localizedDescription)")
        }
        state = .unauthenticated
    }

    private func parseExpiresAt(_ expiresAt: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: expiresAt)
            ?? ISO8601DateFormatter().date(from: expiresAt)
    }
}

private extension AuthSessionManager.State {
    var label: String {
        switch self {
        case .loading: return "loading"
        case .authenticated: return "authenticated"
        case .unauthenticated: return "unauthenticated"
        }
    }
}

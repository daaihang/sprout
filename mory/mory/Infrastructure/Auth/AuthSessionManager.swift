import Foundation
import os

/// Manages the app-wide authentication session.
///
/// On launch, checks Keychain for a persisted credential:
/// - Valid token → authenticated immediately (no login screen)
/// - Expired token → attempts silent refresh via `/auth/refresh`
/// - No token → shows sign-in view
@MainActor
@Observable
final class AuthSessionManager {

    enum State: Sendable {
        case loading
        case authenticated
        case unauthenticated
    }

    private(set) var state: State = .loading

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
        let credential = await credentialStore.loadCredential()

        guard let credential else {
            logger.info("No stored credential — showing sign-in")
            state = .unauthenticated
            return
        }

        if credential.isGuest {
            logger.info("Guest credential found — entering guest mode")
            state = .authenticated
            return
        }

        if !credential.isExpired {
            logger.info("Valid credential found — user \(credential.userID)")
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
    func didSignIn(identityToken: String, userID: String) async {
        do {
            let authResponse = try await apiClient.authenticate(identityToken: identityToken)
            let credential = AuthCredential(
                accessToken: authResponse.accessToken,
                refreshToken: authResponse.refreshToken ?? authResponse.accessToken,
                expiresAt: parseExpiresAt(authResponse.expiresAt),
                userID: authResponse.user.id,
                identityToken: identityToken
            )
            try await credentialStore.saveCredential(credential)
            logger.info("Sign-in successful — user \(credential.userID)")
            state = .authenticated
        } catch {
            logger.error("Sign-in authentication failed: \(error.localizedDescription)")
            await clearAndSignOut()
        }
    }

    /// Called for guest mode.
    func continueAsGuest() async {
        do {
            try await credentialStore.saveCredential(.guest)
            state = .authenticated
        } catch {
            logger.error("Failed to save guest credential: \(error.localizedDescription)")
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
        state = .unauthenticated
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
            state = .authenticated
        } catch {
            logger.warning("Token refresh failed: \(error.localizedDescription)")
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
            state = .authenticated
        } catch {
            logger.warning("Re-authentication failed: \(error.localizedDescription)")
            await clearAndSignOut()
        }
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

import Foundation
import AuthenticationServices

@MainActor
final class AppleAuthService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var userIdentifier: String?
    @Published var errorMessage: String?

    private let credentialStore: KeychainCredentialStore
    private var continuation: CheckedContinuation<ASAuthorization, Error>?

    init(credentialStore: KeychainCredentialStore) {
        self.credentialStore = credentialStore
        super.init()
    }

    func checkExistingCredential() async {
        do {
            let userId = try await credentialStore.getUserIdentifier()
            if userId != nil {
                isAuthorized = true
                userIdentifier = userId
            }
        } catch {
            isAuthorized = false
        }
    }

    func signIn() async throws -> String {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self

        controller.performRequests()

        let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            self.continuation = continuation
        }

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleAuthError.invalidCredential
        }

        let identityToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        guard let token = identityToken else {
            throw AppleAuthError.missingIdentityToken
        }

        let userId = appleIDCredential.user
        try await credentialStore.save(identityToken: token, userIdentifier: userId)

        isAuthorized = true
        userIdentifier = userId

        return token
    }

    func signOut() async throws {
        try await credentialStore.delete()
        isAuthorized = false
        userIdentifier = nil
    }

    enum AppleAuthError: Error, LocalizedError {
        case invalidCredential
        case missingIdentityToken
        case cancelled

        var errorDescription: String? {
            switch self {
            case .invalidCredential:
                return "Invalid credential received from Apple."
            case .missingIdentityToken:
                return "Missing identity token from Apple."
            case .cancelled:
                return "Sign in was cancelled."
            }
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            continuation?.resume(returning: authorization)
            continuation = nil
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                continuation?.resume(throwing: AppleAuthError.cancelled)
            } else {
                continuation?.resume(throwing: error)
            }
            continuation = nil
        }
    }
}
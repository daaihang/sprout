import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let authManager: AuthSessionManager?

    init(credentialStore: KeychainCredentialStore, authManager: AuthSessionManager? = nil) {
        _ = credentialStore
        self.authManager = authManager
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)

                Text("Mory")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("signin.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 16) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await handleSignInResult(result)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                #if DEBUG
                Button("signin.guest") {
                    Task {
                        await authManager?.continueAsGuest()
                    }
                }
                .foregroundStyle(.secondary)
                #endif
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid credential from Apple."
                return
            }

            let identityToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
            let userId = appleIDCredential.user

            let didComplete = await authManager?.didSignIn(identityToken: identityToken ?? "", userID: userId) ?? false
            if didComplete {
                errorMessage = nil
            } else {
                errorMessage = authManager?.lastErrorMessage ?? "Sign in failed."
            }

        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                return
            }
            if let authError = error as? AppleAuthService.AppleAuthError, case .cancelled = authError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}

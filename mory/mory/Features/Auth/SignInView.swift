import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @StateObject private var authService: AppleAuthService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onSignedIn: (() -> Void)?

    init(credentialStore: KeychainCredentialStore, onSignedIn: (() -> Void)? = nil) {
        _authService = StateObject(wrappedValue: AppleAuthService(credentialStore: credentialStore))
        self.onSignedIn = onSignedIn
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
                    onSignedIn?()
                }
                .foregroundStyle(.secondary)
                #endif
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 60)
        }
        .task {
            await authService.checkExistingCredential()
            if authService.isAuthorized {
                onSignedIn?()
            }
        }
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        defer { isLoading = false }

        switch result {
        case .success:
            errorMessage = nil
            onSignedIn?()
        case .failure(let error):
            if let asError = error as? ASAuthorizationError, asError.code == .canceled {
                // User cancelled — silently dismiss, no error shown
                return
            }
            if let authError = error as? AppleAuthService.AppleAuthError, case .cancelled = authError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }
}
import AuthenticationServices
import SwiftUI

struct AuthLandingView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AuthSessionManager.self) private var authSession
    @State private var currentNonce = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.89, blue: 0.80),
                    Color(red: 0.87, green: 0.93, blue: 0.88),
                    Color(red: 0.81, green: 0.89, blue: 0.97),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Spacer()

                    if canSkipSignIn {
                        Button(t("common.skip", "Skip")) {
                            authSession.signInForDevelopmentBypass()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "tree.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color(red: 0.16, green: 0.42, blue: 0.31))
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    Text(localization.string("auth.title", default: "Let your memories take root"))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(localization.string("auth.subtitle", default: "Sign in with Apple to securely sync your private journaling space across devices."))
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320)
                }

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { request in
                        let nonce = AppleNonce.random()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = AppleNonce.sha256(nonce)
                    } onCompletion: { result in
                        handle(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(authSession.isAuthenticating)

                    Text(localization.string("auth.privacy", default: "We use Apple Sign In only for authentication. Your records remain on your device and iCloud."))
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 320)

                    if let errorMessage = authSession.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .padding(.horizontal, 24)

                Spacer()

                Text(localization.string("auth.footer", default: "Requires Sign in with Apple capability on the app ID and an Apple ID signed in on the simulator or device."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
    }

    private func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                authSession.errorMessage = AuthError.missingIdentityToken.localizedDescription
                return
            }

            Task {
                await authSession.signInWithApple(
                    payload: .init(identityToken: identityToken, rawNonce: currentNonce)
                )
            }
        case let .failure(error):
            authSession.errorMessage = error.localizedDescription
        }
    }

    private var canSkipSignIn: Bool {
#if targetEnvironment(simulator)
        true
#elseif DEBUG
        true
#else
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
#endif
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

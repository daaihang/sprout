import SwiftUI

struct AuthGateView: View {
    @Environment(AuthSessionManager.self) private var authSession
    @Environment(BiometricLockManager.self) private var biometricLock
    @Environment(AppLocalization.self) private var localization

    var body: some View {
        switch authSession.state {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .signedOut:
            AuthLandingView()
        case .signedIn:
            Group {
                if biometricLock.isEnabled && !biometricLock.isUnlocked {
                    biometricLockView
                } else {
                    ContentView()
                }
            }
            .task {
                await biometricLock.authenticateIfNeeded()
            }
        }
    }

    private var biometricLockView: some View {
        VStack(spacing: 20) {
            Image(systemName: biometricLock.biometricKind.iconName)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.primary)

            Text(biometricLock.biometricKind.title)
                .font(.title3.weight(.semibold))

            if let message = biometricLock.lastErrorMessage, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(t("account.biometric.unlock", "Unlock")) {
                Task {
                    await biometricLock.authenticateIfNeeded()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

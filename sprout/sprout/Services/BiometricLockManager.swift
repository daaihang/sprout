import Foundation
import LocalAuthentication
import Observation

@Observable
@MainActor
final class BiometricLockManager {
    enum BiometricKind {
        case none
        case faceID
        case touchID

        var title: String {
            switch self {
            case .none:
                return localizedString("account.biometric.generic", default: "Biometric Lock")
            case .faceID:
                return localizedString("account.biometric.face_id", default: "Face ID")
            case .touchID:
                return localizedString("account.biometric.touch_id", default: "Touch ID")
            }
        }

        var settingsTitle: String {
            switch self {
            case .none:
                return localizedString("account.row.biometric_lock", default: "Biometric Lock")
            case .faceID:
                return localizedString("account.row.face_id_lock", default: "Face ID Lock")
            case .touchID:
                return localizedString("account.row.touch_id_lock", default: "Touch ID Lock")
            }
        }

        var iconName: String {
            switch self {
            case .none:
                return "lock"
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            }
        }
    }

    private enum Keys {
        static let isEnabled = "settings.biometric_lock.enabled"
    }

    var isEnabled: Bool
    var isUnlocked = false
    var lastErrorMessage: String? = nil

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
    }

    var biometricKind: BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    var isAvailable: Bool {
        biometricKind != .none
    }

    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            isEnabled = false
            isUnlocked = false
            lastErrorMessage = nil
            UserDefaults.standard.set(false, forKey: Keys.isEnabled)
            return true
        }

        let success = await authenticate(reason: localizedString("account.biometric.enable_reason", default: "Authenticate to enable biometric lock."))
        if success {
            isEnabled = true
            isUnlocked = true
            UserDefaults.standard.set(true, forKey: Keys.isEnabled)
        }
        return success
    }

    func authenticateIfNeeded() async {
        guard isEnabled else {
            isUnlocked = true
            return
        }

        guard !isUnlocked else { return }
        _ = await authenticate(reason: localizedString("account.biometric.unlock_reason", default: "Unlock Sprout."))
    }

    func lock() {
        guard isEnabled else { return }
        isUnlocked = false
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = localizedString("common.cancel", default: "Cancel")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            lastErrorMessage = error?.localizedDescription
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                lastErrorMessage = nil
            }
            isUnlocked = success
            return success
        } catch {
            lastErrorMessage = error.localizedDescription
            isUnlocked = false
            return false
        }
    }
}

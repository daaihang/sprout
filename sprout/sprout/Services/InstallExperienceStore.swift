import Foundation
import Observation

@Observable
@MainActor
final class InstallExperienceStore {
    private let hasSeenWelcomeKey = "install.has_seen_welcome"
    private let forceShowWelcomeKey = "debug.force_show_welcome"
    private let forceRequireSignedInOnboardingKey = "debug.force_require_signed_in_onboarding"

    var hasSeenWelcome: Bool
    var forceShowWelcome: Bool
    var forceRequireSignedInOnboarding: Bool

    init(defaults: UserDefaults = .standard) {
        hasSeenWelcome = defaults.bool(forKey: hasSeenWelcomeKey)
        forceShowWelcome = defaults.bool(forKey: forceShowWelcomeKey)
        forceRequireSignedInOnboarding = defaults.bool(forKey: forceRequireSignedInOnboardingKey)
    }

    func markWelcomeSeen(defaults: UserDefaults = .standard) {
        hasSeenWelcome = true
        defaults.set(true, forKey: hasSeenWelcomeKey)
    }

    func resetWelcome(defaults: UserDefaults = .standard) {
        hasSeenWelcome = false
        defaults.set(false, forKey: hasSeenWelcomeKey)
    }

    func setForceShowWelcome(_ enabled: Bool, defaults: UserDefaults = .standard) {
        forceShowWelcome = enabled
        defaults.set(enabled, forKey: forceShowWelcomeKey)
    }

    func setForceRequireSignedInOnboarding(_ enabled: Bool, defaults: UserDefaults = .standard) {
        forceRequireSignedInOnboarding = enabled
        defaults.set(enabled, forKey: forceRequireSignedInOnboardingKey)
    }
}

import Foundation

enum MoryConfig {
    /// RevenueCat API key injected at build time from Debug.xcconfig / Release.xcconfig
    /// via the REVENUECAT_API_KEY entry in Info.plist.
    static var revenueCatAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("appl_REPLACE") else {
            assertionFailure("""
                REVENUECAT_API_KEY is not configured.
                Open sprout/Config/Debug.xcconfig and replace the placeholder with your
                RevenueCat Sandbox API key, then verify xcconfig files are assigned to
                Debug/Release build configurations in the project's Info tab.
            """)
            return ""
        }
        return key
    }

    private static func string(for key: String, fallback: String = "") -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            return fallback
        }
        return value
    }

    private static func stringList(for key: String) -> [String] {
        string(for: key)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    enum ProductID {
        static let monthlyGrow = string(for: "REVENUECAT_MONTHLY_PRODUCT_ID", fallback: "com.speculolabs.sprout.grow.monthly")
        static let yearlyGrow  = string(for: "REVENUECAT_YEARLY_PRODUCT_ID", fallback: "com.speculolabs.sprout.grow.yearly")
    }

    static let entitlementID = string(for: "REVENUECAT_ENTITLEMENT_ID", fallback: "Sprout Grow")
    static let entitlementFallbackIDs = stringList(for: "REVENUECAT_ENTITLEMENT_FALLBACK_IDS")
    static let offeringID = string(for: "REVENUECAT_OFFERING_ID", fallback: "sprout_grow")
    static var apiBaseURL: String {
        let scheme = string(for: "MORY_API_SCHEME", fallback: "http")
        let host = string(for: "MORY_API_HOST", fallback: "127.0.0.1")
        let port = string(for: "MORY_API_PORT", fallback: "8080")

        if !isRunningOnSimulator, isLocalhost(host) {
            return "https://sprout-god7g.fly.dev"
        }

        guard !scheme.isEmpty, !host.isEmpty else {
            return "http://127.0.0.1:8080"
        }

        if port.isEmpty {
            return "\(scheme)://\(host)"
        }

        return "\(scheme)://\(host):\(port)"
    }

    private static var isRunningOnSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static func isLocalhost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "localhost" || normalized == "127.0.0.1" || normalized == "::1"
    }
}

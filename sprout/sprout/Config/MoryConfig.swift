import Foundation

enum MoryConfig {
    /// RevenueCat API key injected at build time from Debug.xcconfig / Release.xcconfig
    /// via the REVENUECAT_API_KEY entry in Info.plist.
    static var revenueCatAPIKey: String {
        guard let key = Bundle.main.infoDictionary?["REVENUECAT_API_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("appl_REPLACE"),
              !key.hasPrefix("test_REPLACE") else {
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
        let baseURL = string(for: "MORY_API_BASE_URL", fallback: "")
        if !baseURL.isEmpty {
            return baseURL
        }
        return "https://sprout-god7g.fly.dev"
    }

    static var apiHost: String {
        URL(string: apiBaseURL)?.host ?? apiBaseURL
    }
}

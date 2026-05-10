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

    enum ProductID {
        static let monthlyGrow = "com.speculolabs.sprout.grow.monthly"
        static let yearlyGrow  = "com.speculolabs.sprout.grow.yearly"
    }

    static let entitlementID = "grow"
    static let offeringID    = "default"
}

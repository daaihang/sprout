import Foundation

struct AppRuntimeEnvironment: Hashable, Sendable {
    enum BuildChannel: String, Sendable {
        case internalBeta = "InternalBeta"
        case publicBeta = "PublicBeta"
        case production = "Production"
        case unknown = "Unknown"

        init(rawBundleValue: String?) {
            let normalized = rawBundleValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            switch normalized {
            case "internal", "internalbeta", "internal_beta":
                self = .internalBeta
            case "public", "publicbeta", "public_beta", "beta":
                self = .publicBeta
            case "production", "prod", "appstore", "app_store", "release":
                self = .production
            default:
                self = .unknown
            }
        }

        var label: String {
            rawValue
        }
    }

    enum Distribution: String, Sendable {
        case debug = "Debug"
        case development = "Development"
        case testFlight = "TestFlight"
        case appStore = "AppStore"
    }

    let buildChannel: BuildChannel
    let distribution: Distribution
    let bundleIdentifier: String
    let version: String
    let buildNumber: String

    static var current: AppRuntimeEnvironment {
        AppRuntimeEnvironment(bundle: .main)
    }

    init(
        buildChannel: BuildChannel,
        distribution: Distribution,
        bundleIdentifier: String,
        version: String,
        buildNumber: String
    ) {
        self.buildChannel = buildChannel
        self.distribution = distribution
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.buildNumber = buildNumber
    }

    init(bundle: Bundle) {
        self.init(
            buildChannel: BuildChannel(rawBundleValue: bundle.object(forInfoDictionaryKey: "MORY_BUILD_CHANNEL") as? String),
            distribution: Self.detectDistribution(bundle: bundle),
            bundleIdentifier: bundle.bundleIdentifier ?? "unknown",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }

    var allowsDebugTools: Bool {
        switch distribution {
        case .debug, .development:
            return true
        case .testFlight:
            return buildChannel == .internalBeta
        case .appStore:
            return false
        }
    }

    var label: String {
        "\(buildChannel.label) / \(distribution.rawValue)"
    }

    private static func detectDistribution(bundle: Bundle) -> Distribution {
        #if DEBUG
        return .debug
        #else
        guard let receiptURL = bundle.appStoreReceiptURL else {
            return .development
        }

        if receiptURL.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }

        if FileManager.default.fileExists(atPath: receiptURL.path) {
            return .appStore
        }

        return .development
        #endif
    }
}

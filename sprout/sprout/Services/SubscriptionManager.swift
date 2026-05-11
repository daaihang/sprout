import Foundation
import Observation

#if canImport(RevenueCat)
import RevenueCat

@Observable
@MainActor
final class SubscriptionManager {
    enum PackageKind: String {
        case monthly
        case yearly

        var sortOrder: Int {
            switch self {
            case .monthly:
                return 0
            case .yearly:
                return 1
            }
        }
    }

    struct PackageSummary: Identifiable {
        let kind: PackageKind
        let title: String
        let price: String
        let package: Package

        var id: String { kind.rawValue }
    }

    var isSubscribed = false
    var availablePackages: [Package] = []
    var packageSummaries: [PackageSummary] = []
    var isLoading = false
    var errorMessage: String? = nil
    var customerInfo: CustomerInfo? = nil
    var currentPackageKind: PackageKind? = nil
    var expirationDate: Date? = nil
    var loadedProductIDs: [String] = []

    init() {
        configure()
    }

    private func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif

        Purchases.configure(withAPIKey: MoryConfig.revenueCatAPIKey)

        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let offerings = try await Purchases.shared.offerings()
            let targetOffering = offerings.offering(identifier: MoryConfig.offeringID)
            let packages = targetOffering?.availablePackages ?? []
            if targetOffering == nil {
                errorMessage = AppLocalization.shared.string(
                    "subscription.error.offering_not_found",
                    default: "RevenueCat offering not found: %@",
                    table: "Subscription",
                    arguments: [MoryConfig.offeringID]
                )
            }
            availablePackages = packages
            loadedProductIDs = packages.map { $0.storeProduct.productIdentifier }
            packageSummaries = packages.compactMap(makeSummary(for:)).sorted { lhs, rhs in
                lhs.kind.sortOrder < rhs.kind.sortOrder
            }
            if let customerInfo {
                apply(customerInfo)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCustomerInfo() async {
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(kind: PackageKind) async throws {
        guard let package = package(for: kind) else {
            errorMessage = AppLocalization.shared.string(
                "subscription.error.package_not_found",
                default: "The selected subscription package could not be found.",
                table: "Subscription"
            )
            return
        }
        try await purchase(package: package)
    }

    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            apply(try await Purchases.shared.restorePurchases())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func package(for kind: PackageKind) -> Package? {
        availablePackages.first(where: { packageKind(for: $0) == kind })
    }

    func summary(for kind: PackageKind) -> PackageSummary? {
        packageSummaries.first(where: { $0.kind == kind })
    }

    private func apply(_ info: CustomerInfo) {
        customerInfo = info

        let entitlement = resolvedEntitlement(from: info)
        isSubscribed = entitlement?.isActive == true
        expirationDate = entitlement?.expirationDate

        let activeProductIDs = Set(info.activeSubscriptions)
        currentPackageKind = packageSummaries
            .first(where: { activeProductIDs.contains($0.package.storeProduct.productIdentifier) })?
            .kind

        if currentPackageKind == nil {
            currentPackageKind = packageKind(forProductID: entitlement?.productIdentifier)
        }
    }

    private func resolvedEntitlement(from info: CustomerInfo) -> EntitlementInfo? {
        if let exact = info.entitlements[MoryConfig.entitlementID] {
            return exact
        }

        for fallbackID in MoryConfig.entitlementFallbackIDs {
            if let fallback = info.entitlements[fallbackID] {
                return fallback
            }
        }

        return nil
    }

    private func makeSummary(for package: Package) -> PackageSummary? {
        guard let kind = packageKind(for: package) else { return nil }

        return PackageSummary(
            kind: kind,
            title: package.storeProduct.localizedTitle,
            price: package.localizedPriceString,
            package: package
        )
    }

    private func packageKind(for package: Package) -> PackageKind? {
        packageKind(forProductID: package.storeProduct.productIdentifier)
    }

    private func packageKind(forProductID productID: String?) -> PackageKind? {
        switch productID {
        case MoryConfig.ProductID.monthlyGrow:
            return .monthly
        case MoryConfig.ProductID.yearlyGrow:
            return .yearly
        default:
            return nil
        }
    }

}

#else

@Observable
@MainActor
final class SubscriptionManager {
    enum PackageKind: String {
        case monthly
        case yearly
    }

    struct PackageSummary: Identifiable {
        let kind: PackageKind
        let title: String
        let price: String

        var id: String { kind.rawValue }
    }

    var isSubscribed = false
    var availablePackages: [Any] = []
    var packageSummaries: [PackageSummary] = []
    var isLoading = false
    var errorMessage: String? = AppLocalization.shared.string(
        "subscription.error.sdk_missing",
        default: "RevenueCat SDK is not installed.",
        table: "Subscription"
    )
    var customerInfo: Any? = nil
    var currentPackageKind: PackageKind? = nil
    var expirationDate: Date? = nil
    var loadedProductIDs: [String] = []

    init() {}
    func loadOfferings() async {}
    func refreshCustomerInfo() async {}
    func restorePurchases() async {}
    func purchase(kind: PackageKind) async throws {}
    func summary(for kind: PackageKind) -> PackageSummary? { nil }
}

#endif

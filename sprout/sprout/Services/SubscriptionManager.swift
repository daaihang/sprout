import Foundation
import Observation
import StoreKit

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
        let productID: String
        let package: Package?

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
    private var storeKitProductsByID: [String: Product] = [:]
    private let productConfigurationHint = AppLocalization.shared.string(
        "subscription.error.products_configuration_hint",
        default: "No subscription products could be loaded. On a real device, confirm these product IDs exist in App Store Connect, are approved for the current environment, and are also added to the RevenueCat offering.",
        table: "Subscription"
    )

    init() {
        configure()
    }

    private func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif

        guard !MoryConfig.revenueCatAPIKey.isEmpty else {
            errorMessage = AppLocalization.shared.string(
                "subscription.error.api_key_missing",
                default: "RevenueCat API key is missing.",
                table: "Subscription"
            )
            return
        }

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
            let targetOffering =
                offerings.offering(identifier: MoryConfig.offeringID)
                ?? offerings.current
                ?? offerings.all.values.sorted(by: { $0.identifier < $1.identifier }).first
            let packages = targetOffering?.availablePackages ?? []
            if !packages.isEmpty {
                applyRevenueCatPackages(packages)
                if let customerInfo {
                    await reconcileSubscriptionState(with: customerInfo)
                } else {
                    _ = await refreshStoreKitEntitlements()
                }
                return
            }

            if await loadStoreKitProducts() {
                if let customerInfo {
                    await reconcileSubscriptionState(with: customerInfo)
                } else {
                    _ = await refreshStoreKitEntitlements()
                }
                return
            }

            clearPackages()
            if targetOffering == nil {
                errorMessage = AppLocalization.shared.string(
                    "subscription.error.offering_not_found",
                    default: "RevenueCat offering not found: %@",
                    table: "Subscription",
                    arguments: [MoryConfig.offeringID]
                )
            } else {
                errorMessage = productsUnavailableMessage(
                    AppLocalization.shared.string(
                        "subscription.error.products_unavailable",
                        default: "No subscription products are available.",
                        table: "Subscription"
                    )
                )
            }
        } catch {
            if await loadStoreKitProducts() {
                if let customerInfo {
                    await reconcileSubscriptionState(with: customerInfo)
                } else {
                    _ = await refreshStoreKitEntitlements()
                }
            } else {
                clearPackages()
                errorMessage = productsUnavailableMessage(error.localizedDescription)
            }
        }
    }

    func refreshCustomerInfo() async {
        do {
            await reconcileSubscriptionState(with: try await Purchases.shared.customerInfo())
        } catch {
            if await refreshStoreKitEntitlements() {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func purchase(kind: PackageKind) async throws {
        if let package = package(for: kind) {
            try await purchase(package: package)
            return
        }

        if storeKitProduct(for: kind) == nil {
            _ = await loadStoreKitProducts()
        }

        guard let product = storeKitProduct(for: kind) else {
            errorMessage = AppLocalization.shared.string(
                "subscription.error.package_not_found",
                default: "The selected subscription package could not be found.",
                table: "Subscription"
            )
            return
        }

        try await purchase(product: product)
    }

    func purchase(package: Package) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let result = try await Purchases.shared.purchase(package: package)
        await reconcileSubscriptionState(with: result.customerInfo)
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            await reconcileSubscriptionState(with: try await Purchases.shared.restorePurchases())
        } catch {
            do {
                try await AppStore.sync()
                _ = await refreshStoreKitEntitlements()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func package(for kind: PackageKind) -> Package? {
        availablePackages.first(where: { packageKind(for: $0) == kind })
    }

    func summary(for kind: PackageKind) -> PackageSummary? {
        packageSummaries.first(where: { $0.kind == kind })
    }

    private func reconcileSubscriptionState(with info: CustomerInfo) async {
        apply(info)
        if !isSubscribed {
            _ = await refreshStoreKitEntitlements()
        }
    }

    private func apply(_ info: CustomerInfo) {
        customerInfo = info

        let entitlement = resolvedEntitlement(from: info)
        isSubscribed = entitlement?.isActive == true
        expirationDate = entitlement?.expirationDate

        let activeProductIDs = Set(info.activeSubscriptions)
        currentPackageKind = packageSummaries
            .first(where: { activeProductIDs.contains($0.productID) })?
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
            productID: package.storeProduct.productIdentifier,
            package: package
        )
    }

    private func makeSummary(for product: Product) -> PackageSummary? {
        guard let kind = packageKind(forProductID: product.id) else { return nil }

        return PackageSummary(
            kind: kind,
            title: product.displayName,
            price: product.displayPrice,
            productID: product.id,
            package: nil
        )
    }

    private func packageKind(for package: Package) -> PackageKind? {
        packageKind(forProductID: package.storeProduct.productIdentifier)
    }

    private func packageKind(forProductID productID: String?) -> PackageKind? {
        guard let productID else { return nil }

        if productID == MoryConfig.ProductID.monthlyGrow {
            return .monthly
        }

        if productID == MoryConfig.ProductID.yearlyGrow {
            return .yearly
        }

        let normalized = productID.lowercased()

        if normalized.contains("month") {
            return .monthly
        }

        if normalized.contains("year") || normalized.contains("annual") {
            return .yearly
        }

        return nil
    }

    private func applyRevenueCatPackages(_ packages: [Package]) {
        availablePackages = packages
        loadedProductIDs = packages.map { $0.storeProduct.productIdentifier }
        packageSummaries = packages.compactMap(makeSummary(for:)).sorted { lhs, rhs in
            lhs.kind.sortOrder < rhs.kind.sortOrder
        }
        errorMessage = nil
    }

    private func clearPackages() {
        availablePackages = []
        loadedProductIDs = []
        packageSummaries = []
    }

    private func productsUnavailableMessage(_ message: String) -> String {
        message + "\n\n" + productConfigurationHint
    }

    @discardableResult
    private func loadStoreKitProducts() async -> Bool {
        let productIDs = Set([
            MoryConfig.ProductID.monthlyGrow,
            MoryConfig.ProductID.yearlyGrow
        ].filter { !$0.isEmpty })

        guard !productIDs.isEmpty else {
            clearPackages()
            return false
        }

        do {
            let products = try await Product.products(for: Array(productIDs))
            storeKitProductsByID = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
            loadedProductIDs = products.map(\.id)
            packageSummaries = products.compactMap(makeSummary(for:)).sorted { lhs, rhs in
                lhs.kind.sortOrder < rhs.kind.sortOrder
            }
            availablePackages = []
            if packageSummaries.isEmpty {
                errorMessage = productsUnavailableMessage(
                    AppLocalization.shared.string(
                        "subscription.error.products_unavailable",
                        default: "No subscription products are available.",
                        table: "Subscription"
                    )
                )
            } else {
                errorMessage = nil
            }
            return !packageSummaries.isEmpty
        } catch {
            clearPackages()
            return false
        }
    }

    private func storeKitProduct(for kind: PackageKind) -> Product? {
        switch kind {
        case .monthly:
            return storeKitProductsByID[MoryConfig.ProductID.monthlyGrow]
        case .yearly:
            return storeKitProductsByID[MoryConfig.ProductID.yearlyGrow]
        }
    }

    private func purchase(product: Product) async throws {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            _ = await refreshStoreKitEntitlements()
        case .pending:
            break
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    private func verified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }

    @discardableResult
    private func refreshStoreKitEntitlements() async -> Bool {
        var activeProductIDs = Set<String>()
        var latestExpiration: Date? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            activeProductIDs.insert(transaction.productID)

            if let expiration = transaction.expirationDate {
                latestExpiration = max(latestExpiration ?? expiration, expiration)
            }
        }

        if !activeProductIDs.isEmpty {
            isSubscribed = true
            expirationDate = latestExpiration

            if activeProductIDs.contains(MoryConfig.ProductID.yearlyGrow) {
                currentPackageKind = .yearly
            } else if activeProductIDs.contains(MoryConfig.ProductID.monthlyGrow) {
                currentPackageKind = .monthly
            } else {
                currentPackageKind = activeProductIDs
                    .compactMap(packageKind(forProductID:))
                    .sorted(by: { $0.sortOrder < $1.sortOrder })
                    .first
            }

            return true
        }

        isSubscribed = false
        expirationDate = nil
        currentPackageKind = nil
        return false
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

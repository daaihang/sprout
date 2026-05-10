import Foundation
import Observation

// RevenueCat types are imported conditionally so the file compiles before
// the package is added via SPM. Remove the canImport guard once RevenueCat
// is added to the project (File → Add Package Dependencies).
#if canImport(RevenueCat)
import RevenueCat

@Observable
@MainActor
final class SubscriptionManager {
    var isSubscribed: Bool = false
    var availablePackages: [Package] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var customerInfo: CustomerInfo? = nil

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
        Task { await refreshCustomerInfo() }
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            availablePackages = offerings.current?.availablePackages ?? []
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

    private func apply(_ info: CustomerInfo) {
        customerInfo = info
        isSubscribed = info.entitlements[MoryConfig.entitlementID]?.isActive == true
    }
}

#else

// Stub used before RevenueCat SPM package is added.
// Once you add https://github.com/RevenueCat/purchases-ios via
// File → Add Package Dependencies, this stub is automatically replaced.
@Observable
@MainActor
final class SubscriptionManager {
    var isSubscribed: Bool = false
    var availablePackages: [Any] = []
    var isLoading: Bool = false
    var errorMessage: String? = "RevenueCat SDK not yet installed — add via SPM"
    var customerInfo: Any? = nil

    init() {}
    func loadOfferings() async {}
    func refreshCustomerInfo() async {}
    func restorePurchases() async {}
}

#endif

import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct SubscriptionDebugView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(SubscriptionManager.self) private var manager
    @State private var purchaseError: String? = nil

    var body: some View {
        List {
            statusSection
            packagesSection
            if let err = purchaseError ?? manager.errorMessage {
                Section(t("common.error", "Error")) {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            actionsSection
            configSection
        }
        .navigationTitle(t("subscription.debug.title", "Subscription Debug"))
        .task { await manager.loadOfferings() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section(t("subscription.debug.section.status", "Subscription Status")) {
            HStack {
                Label(
                    manager.isSubscribed ? t("subscription.debug.status.subscribed", "Subscribed") : t("subscription.debug.status.not_subscribed", "Not Subscribed"),
                    systemImage: manager.isSubscribed ? "checkmark.seal.fill" : "xmark.seal"
                )
                .foregroundStyle(manager.isSubscribed ? .green : .secondary)
                Spacer()
                Text(manager.isSubscribed ? t("common.yes", "Yes") : t("common.no", "No"))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            customerInfoRows
        }
    }

    @ViewBuilder
    private var customerInfoRows: some View {
        #if canImport(RevenueCat)
        if let info = manager.customerInfo {
            let subs = info.activeSubscriptions
            HStack {
                Text(t("subscription.debug.row.active_subscriptions", "Active Subscriptions"))
                Spacer()
                Text(subs.isEmpty ? t("common.none", "None") : subs.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let entitlement = resolvedEntitlement(from: info) {
                HStack {
                    Text(t("subscription.debug.row.grow_entitlement", "Grow Entitlement"))
                    Spacer()
                    Text(entitlement.isActive ? t("subscription.debug.status.active", "Active") : t("subscription.debug.status.inactive", "Inactive"))
                        .foregroundStyle(entitlement.isActive ? .green : .orange)
                        .font(.caption)
                }
                if let expiry = entitlement.expirationDate {
                    HStack {
                        Text(t("subscription.debug.row.expiration_date", "Expiration Date"))
                        Spacer()
                        Text(expiry, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        #endif
    }

    @ViewBuilder
    private var packagesSection: some View {
        Section(t("subscription.debug.section.packages", "Available Packages (RevenueCat)")) {
            if manager.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if manager.availablePackages.isEmpty {
                Text(t("subscription.debug.empty_packages", "No packages loaded. Tap Refresh Packages below."))
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                #if canImport(RevenueCat)
                ForEach(manager.availablePackages, id: \.identifier) { pkg in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(pkg.storeProduct.localizedTitle)
                                .font(.system(size: 15, weight: .medium))
                            Spacer()
                            Text(pkg.localizedPriceString)
                                .foregroundStyle(.secondary)
                        }
                        Text(pkg.storeProduct.productIdentifier)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Button(t("common.purchase", "Purchase")) {
                            Task {
                                do {
                                    try await manager.purchase(package: pkg)
                                } catch {
                                    purchaseError = error.localizedDescription
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(manager.isLoading)
                    }
                    .padding(.vertical, 4)
                }
                #endif
            }
        }
    }

    private var actionsSection: some View {
        Section(t("subscription.debug.section.actions", "Actions")) {
            Button(t("common.refresh_packages", "Refresh Packages")) { Task { await manager.loadOfferings() } }
                .disabled(manager.isLoading)
            Button(t("common.restore_purchases", "Restore Purchases")) { Task { await manager.restorePurchases() } }
                .disabled(manager.isLoading)
            Button(t("subscription.debug.refresh_customer", "Refresh Customer Status")) { Task { await manager.refreshCustomerInfo() } }
                .disabled(manager.isLoading)
        }
    }

    private var configSection: some View {
        Section(t("subscription.debug.section.config", "Config (Debug)")) {
            let key = MoryConfig.revenueCatAPIKey
            infoRow(t("subscription.debug.row.api_key_prefix", "API Key Prefix"), value: key.count > 12 ? String(key.prefix(12)) + "…" : key)
            infoRow(t("subscription.debug.row.entitlement_id", "Entitlement ID"), value: MoryConfig.entitlementID)
            infoRow(t("subscription.debug.row.offering_id", "Offering ID"), value: MoryConfig.offeringID)
            infoRow(t("subscription.debug.row.monthly_product_id", "Monthly Product ID"), value: MoryConfig.ProductID.monthlyGrow)
            infoRow(t("subscription.debug.row.yearly_product_id", "Yearly Product ID"), value: MoryConfig.ProductID.yearlyGrow)
        }
    }

    #if canImport(RevenueCat)
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
    #endif

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

#Preview {
    NavigationStack {
        SubscriptionDebugView()
            .environment(SubscriptionManager())
    }
}

import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif

struct SubscriptionDebugView: View {
    @Environment(SubscriptionManager.self) private var manager
    @State private var purchaseError: String? = nil

    var body: some View {
        List {
            statusSection
            packagesSection
            if let err = purchaseError ?? manager.errorMessage {
                Section("错误") {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            actionsSection
            configSection
        }
        .navigationTitle("订阅调试")
        .task { await manager.loadOfferings() }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section("订阅状态") {
            HStack {
                Label(
                    manager.isSubscribed ? "已订阅" : "未订阅",
                    systemImage: manager.isSubscribed ? "checkmark.seal.fill" : "xmark.seal"
                )
                .foregroundStyle(manager.isSubscribed ? .green : .secondary)
                Spacer()
                Text(manager.isSubscribed ? "是" : "否")
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
                Text("活跃订阅")
                Spacer()
                Text(subs.isEmpty ? "无" : subs.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if let entitlement = info.entitlements[MoryConfig.entitlementID] {
                HStack {
                    Text("Grow 权益")
                    Spacer()
                    Text(entitlement.isActive ? "活跃" : "未活跃")
                        .foregroundStyle(entitlement.isActive ? .green : .orange)
                        .font(.caption)
                }
                if let expiry = entitlement.expirationDate {
                    HStack {
                        Text("到期时间")
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
        Section("可用套餐 (RevenueCat)") {
            if manager.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if manager.availablePackages.isEmpty {
                Text("未加载套餐 — 点击下方「刷新套餐」")
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
                        Button("购买") {
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
        Section("操作") {
            Button("刷新套餐") { Task { await manager.loadOfferings() } }
                .disabled(manager.isLoading)
            Button("恢复购买") { Task { await manager.restorePurchases() } }
                .disabled(manager.isLoading)
            Button("刷新用户状态") { Task { await manager.refreshCustomerInfo() } }
                .disabled(manager.isLoading)
        }
    }

    private var configSection: some View {
        Section("配置信息 (Debug)") {
            let key = MoryConfig.revenueCatAPIKey
            infoRow("API Key 前缀", value: key.count > 12 ? String(key.prefix(12)) + "…" : key)
            infoRow("Entitlement ID",  value: MoryConfig.entitlementID)
            infoRow("月度 Product ID", value: MoryConfig.ProductID.monthlyGrow)
            infoRow("年度 Product ID", value: MoryConfig.ProductID.yearlyGrow)
        }
    }

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
}

#Preview {
    NavigationStack {
        SubscriptionDebugView()
            .environment(SubscriptionManager())
    }
}

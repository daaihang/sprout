import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLocalization.self) private var localization
    @Environment(SubscriptionManager.self) private var manager

    @State private var selectedKind: SubscriptionManager.PackageKind = .yearly

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                heroSection
                packageSection
                actionSection
                featureSection
                footnoteSection
                debugSection
            }
            .padding(20)
        }
        .background(background)
        .navigationTitle(t("paywall.title", "Upgrade to Grow"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await manager.loadOfferings()
            await manager.refreshCustomerInfo()
            syncSelectionIfNeeded()
        }
        .onChange(of: manager.packageSummaries.count) { _, _ in
            syncSelectionIfNeeded()
        }
        .onChange(of: manager.currentPackageKind) { _, _ in
            syncSelectionIfNeeded()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.98, blue: 0.94),
                Color(red: 0.91, green: 0.96, blue: 0.89),
                Color.white
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("subscription.plan.grow", "Grow Plan"))
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text(t("paywall.hero.subtitle", "Unlock monthly and yearly subscriptions and manage advanced features in one place."))
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                heroPill(t("paywall.hero.pill.ai", "AI Insights"))
                heroPill(t("paywall.hero.pill.relationships", "Relationship Map"))
                heroPill(t("paywall.hero.pill.review", "Advanced Review"))
            }
        }
    }

    private func heroPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.green.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.72), in: Capsule())
    }

    private var packageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("paywall.section.choose_plan", "Choose a Plan"))
                .font(.system(size: 18, weight: .semibold))

            if manager.packageSummaries.isEmpty {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 112)
                    .overlay {
                        if manager.isLoading {
                            ProgressView()
                        } else {
                            Text(t("paywall.packages.empty", "No subscription packages loaded yet."))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }
            } else {
                VStack(spacing: 12) {
                    ForEach(manager.packageSummaries) { summary in
                        packageCard(summary)
                    }
                }
            }
        }
    }

    private func packageCard(_ summary: SubscriptionManager.PackageSummary) -> some View {
        let isSelected = selectedKind == summary.kind
        let isCurrent = manager.currentPackageKind == summary.kind && manager.isSubscribed

        return Button {
            selectedKind = summary.kind
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(summary.title)
                                .font(.system(size: 17, weight: .semibold))

                            if let badge = badge(for: summary.kind) {
                                Text(badge)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green, in: Capsule())
                            }

                            if isCurrent {
                                Text(t("paywall.plan.current", "Current Plan"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.12), in: Capsule())
                            }
                        }

                        Text(subtitle(for: summary.kind))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.5))
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(summary.price)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(periodLabel(for: summary.kind))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? Color.green : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            if let errorMessage = manager.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    try? await manager.purchase(kind: selectedKind)
                    if manager.isSubscribed {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    Spacer()
                    if manager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(manager.isSubscribed ? t("paywall.action.renew", "Change or Renew") : t("paywall.action.subscribe", "Subscribe Now"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(manager.isLoading || manager.summary(for: selectedKind) == nil)

            HStack {
                Button(t("common.restore_purchases", "Restore Purchases")) {
                    Task { await manager.restorePurchases() }
                }
                .disabled(manager.isLoading)

                Spacer()

                Button(t("common.refresh_packages", "Refresh Packages")) {
                    Task { await manager.loadOfferings() }
                }
                .disabled(manager.isLoading)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(t("paywall.section.features", "Included Features"))
                .font(.system(size: 18, weight: .semibold))

            VStack(spacing: 10) {
                featureRow(
                    t("paywall.feature.ai.title", "AI Insights"),
                    t("paywall.feature.ai.subtitle", "Deeper summaries and analysis of your records.")
                )
                featureRow(
                    t("paywall.feature.relationships.title", "Relationship Map"),
                    t("paywall.feature.relationships.subtitle", "See connections between people and events.")
                )
                featureRow(
                    t("paywall.feature.review.title", "Advanced Review"),
                    t("paywall.feature.review.subtitle", "Review your records by topic and time.")
                )
            }
        }
    }

    private func featureRow(_ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .foregroundStyle(.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var footnoteSection: some View {
        Text(t("paywall.footnote", "Subscriptions renew automatically until canceled in App Store settings. Restore purchases works with the same Apple ID."))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(t("common.debug", "Debug"))
                .font(.system(size: 14, weight: .semibold))
            debugRow(t("paywall.debug.api_key", "API Key"), value: MoryConfig.revenueCatAPIKey.isEmpty ? "empty" : String(MoryConfig.revenueCatAPIKey.prefix(12)) + "…")
            debugRow(t("paywall.debug.offering", "Offering"), value: MoryConfig.offeringID)
            debugRow(t("paywall.debug.entitlement", "Entitlement"), value: MoryConfig.entitlementID)
            debugRow(t("paywall.debug.fallbacks", "Fallbacks"), value: fallbackDisplayValue)
            debugRow(t("paywall.debug.monthly_id", "Monthly ID"), value: MoryConfig.ProductID.monthlyGrow)
            debugRow(t("paywall.debug.yearly_id", "Yearly ID"), value: MoryConfig.ProductID.yearlyGrow)
            debugRow(t("paywall.debug.loaded_product_ids", "Loaded Product IDs"), value: manager.loadedProductIDs.isEmpty ? t("common.none", "None") : manager.loadedProductIDs.joined(separator: ", "))
            debugRow(t("paywall.debug.selected_kind", "Selected Kind"), value: selectedKind.rawValue)
            debugRow(t("paywall.debug.loaded_packages", "Loaded Packages"), value: "\(manager.packageSummaries.count)")
            debugRow(t("common.error", "Error"), value: manager.errorMessage ?? t("common.none", "None"))
        }
        .padding(14)
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func debugRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    private var fallbackDisplayValue: String {
        MoryConfig.entitlementFallbackIDs.isEmpty
            ? t("common.none", "None")
            : MoryConfig.entitlementFallbackIDs.joined(separator: ", ")
    }

    private func subtitle(for kind: SubscriptionManager.PackageKind) -> String {
        switch kind {
        case .monthly:
            return t("subscription.summary.monthly_subtitle", "Billed monthly, cancel anytime.")
        case .yearly:
            return t("subscription.summary.yearly_subtitle", "Pay once for the year and save more.")
        }
    }

    private func periodLabel(for kind: SubscriptionManager.PackageKind) -> String {
        switch kind {
        case .monthly:
            return t("subscription.period.month", "/ month")
        case .yearly:
            return t("subscription.period.year", "/ year")
        }
    }

    private func badge(for kind: SubscriptionManager.PackageKind) -> String? {
        switch kind {
        case .monthly:
            return nil
        case .yearly:
            return t("paywall.badge.best_value", "Best Value")
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }

    private func syncSelectionIfNeeded() {
        if let current = manager.currentPackageKind {
            selectedKind = current
        } else if manager.summary(for: .yearly) != nil {
            selectedKind = .yearly
        } else if manager.summary(for: .monthly) != nil {
            selectedKind = .monthly
        }
    }
}

#Preview {
    NavigationStack {
        SubscriptionPaywallView()
            .environment(SubscriptionManager())
    }
}

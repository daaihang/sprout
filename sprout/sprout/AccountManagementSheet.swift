import SwiftUI

struct AccountManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppLocalization.self) private var localization
    @Environment(SubscriptionManager.self) private var subscriptionManager

    @State private var pushTime = Date()
    @State private var showTimePicker = false
    @State private var reminderInterval = 30
    @State private var showReminderPicker = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 用户信息头部
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.blue)

                        VStack(spacing: 4) {
                            Text(t("account.profile.username", "Username"))
                                .font(.system(size: 20, weight: .semibold))

                            Text("user@example.com")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        Text(subscriptionManager.isSubscribed ? t("account.profile.grow_active", "Grow Active") : t("account.profile.free", "Free"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(subscriptionManager.isSubscribed ? Color.green : Color.secondary)
                            .clipShape(Capsule())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)

                // MARK: - 个人设置
                Section(t("account.section.personal", "Personal Settings")) {
                    HStack {
                        SettingsRow(icon: "bell", iconColor: .red, title: t("account.row.daily_prompt", "Daily Prompt Time"), detail: pushTimeString)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTimePicker = true
                    }

                    HStack {
                        SettingsRow(icon: "person.2", iconColor: .orange, title: t("account.row.relationship_interval", "Relationship Reminder Interval"), detail: reminderIntervalString)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showReminderPicker = true
                    }

                    HStack {
                        SettingsRow(icon: "globe", iconColor: .blue, title: t("account.row.app_language", "App Language"), detail: localization.currentLanguage.nativeDisplayName)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openSystemSettings()
                    }

                    SettingsRow(icon: "moon", iconColor: .indigo, title: t("account.row.appearance", "Appearance"), detail: t("common.follow_system", "Follow System"))
                }

                // MARK: - 隐私与安全
                Section(t("account.section.privacy", "Privacy & Security")) {
                    SettingsRow(icon: "faceid", iconColor: .green, title: t("account.row.biometric_lock", "Face ID / Touch ID Lock"))
                    SettingsRow(icon: "square.and.arrow.up", iconColor: .gray, title: t("account.row.export_json", "Export Data (JSON)"))
                }

                // MARK: - 订阅
                Section(t("account.section.subscription", "Subscription")) {
                    NavigationLink(destination: SubscriptionPaywallView()) {
                        HStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.green)
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(t("subscription.plan.grow", "Grow Plan"))
                                    .font(.system(size: 15, weight: .medium))
                                Text(subscriptionStatusDetail)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(subscriptionStatusLabel)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(subscriptionManager.isSubscribed ? .green : .secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Button(t("common.restore_purchases", "Restore Purchases")) {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .disabled(subscriptionManager.isLoading)

                    if let errorMessage = subscriptionManager.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }

                // MARK: - 关于 + 反馈
                Section(t("account.section.about", "About & Feedback")) {
                    SettingsRow(icon: "info.circle", iconColor: .gray, title: t("account.row.version", "Version"), detail: "1.0.5")
                    NavigationLink(destination: Text(t("account.placeholder.rate", "Rating Screen"))) {
                        SettingsRow(icon: "star", iconColor: .yellow, title: t("account.row.rate", "Rate Sprout"))
                    }
                    NavigationLink(destination: Text(t("account.placeholder.feedback", "Feedback Screen"))) {
                        SettingsRow(icon: "envelope", iconColor: .orange, title: t("account.row.feedback", "Send Feedback"))
                    }
                }

                // MARK: - Debug
                Section {
                    NavigationLink(destination: DebugPage()) {
                        HStack(spacing: 12) {
                            Image(systemName: "ant")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Text(t("common.debug", "Debug"))
                        }
                    }
                }

                // MARK: - 退出登录
                Section {
                    Button(t("account.row.logout", "Log Out")) {
                        // logout action
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle(t("account.title", "Account"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await subscriptionManager.refreshCustomerInfo()
                await subscriptionManager.loadOfferings()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t("common.done", "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showTimePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(t("account.sheet.daily_prompt", "Daily Prompt Time"), selection: $pushTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                    .navigationTitle(t("account.sheet.daily_prompt", "Daily Prompt Time"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(t("common.done", "Done")) { showTimePicker = false }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .confirmationDialog(t("account.dialog.relationship_title", "Relationship Reminder Interval"), isPresented: $showReminderPicker) {
                Button(t("account.reminder.days", "%d days", 7)) { reminderInterval = 7 }
                Button(t("account.reminder.days", "%d days", 14)) { reminderInterval = 14 }
                Button(t("account.reminder.days", "%d days", 30)) { reminderInterval = 30 }
                Button(t("common.cancel", "Cancel"), role: .cancel) { }
            }
        }
    }

    private var pushTimeString: String {
        localization.shortTimeString(from: pushTime)
    }

    private var reminderIntervalString: String {
        t("account.reminder.days", "%d days", reminderInterval)
    }

    private var subscriptionStatusLabel: String {
        subscriptionManager.isSubscribed
            ? t("subscription.status.active", "Active")
            : t("subscription.status.upgrade", "Upgrade")
    }

    private var subscriptionStatusDetail: String {
        if subscriptionManager.isSubscribed {
            if let date = subscriptionManager.expirationDate {
                return t("subscription.status.expires", "Expires %@",
                         localization.longDateString(from: date))
            }
            if let kind = subscriptionManager.currentPackageKind {
                return t("subscription.status.plan_active", "%@ active", planName(for: kind))
            }
            return t("subscription.status.active_generic", "Subscription active")
        }

        if let yearly = subscriptionManager.summary(for: .yearly) {
            return t("subscription.status.yearly_price", "Yearly %@%@", yearly.price, periodLabel(for: .yearly))
        }

        if let monthly = subscriptionManager.summary(for: .monthly) {
            return t("subscription.status.monthly_price", "Monthly %@%@", monthly.price, periodLabel(for: .monthly))
        }

        return t("subscription.status.supports_both", "Supports monthly and yearly subscriptions")
    }

    private func planName(for kind: SubscriptionManager.PackageKind) -> String {
        switch kind {
        case .monthly:
            return t("subscription.plan.monthly", "Monthly")
        case .yearly:
            return t("subscription.plan.yearly", "Yearly")
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

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

// MARK: - MemoryOverviewSection

struct MemoryOverviewSection: View {
    @Environment(AppLocalization.self) private var localization

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                // 标题
                HStack {
                    Text(localization.string("account.memory.title", default: "Memory Overview"))
                        .font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Text(localization.string("account.memory.days_recorded", default: "You have recorded with Sprout for %d days", arguments: [128]))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // 统计数字
                HStack(spacing: 12) {
                    StatCard(value: "128", label: localization.string("account.memory.card.days", default: "Days Recorded"), icon: "calendar")
                    StatCard(value: "365", label: localization.string("account.memory.card.records", default: "Total Records"), icon: "doc.text")
                    StatCard(value: "12", label: localization.string("account.memory.card.people", default: "People"), icon: "person.2")
                    StatCard(value: "8", label: localization.string("account.memory.card.decisions", default: "Decisions"), icon: "flag")
                }

                // Year in Pixels 热力图
                YearInPixelsGrid()

                // 成就徽章墙
                BadgeWallView()

                // Top 人物
                TopPeopleRowView()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - StatCard

struct StatCard: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue.opacity(0.70))

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - YearInPixelsGrid

struct YearInPixelsGrid: View {
    @Environment(AppLocalization.self) private var localization
    private let columns = 52 // 52 weeks
    private let rows = 7 // 7 days

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localization.string("account.memory.heatmap", default: "This Year's Heatmap"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: SwiftUI.GridItem(.fixed(6)), count: rows), spacing: 2) {
                    ForEach(0..<365, id: \.self) { index in
                        let intensity = Double.random(in: 0...1)
                        RoundedRectangle(cornerRadius: 1)
                            .fill(intensity > 0.7 ? Color.green : (intensity > 0.3 ? Color.green.opacity(0.5) : Color.gray.opacity(0.2)))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(height: 20)
        }
    }
}

// MARK: - BadgeWallView

struct BadgeWallView: View {
    @Environment(AppLocalization.self) private var localization
    private let badges = [
        ("🎯", "account.badge.first_record", "First Record", true),
        ("🔥", "account.badge.streak_30", "30-Day Streak", true),
        ("👥", "account.badge.remember_10_people", "Remember 10 People", true),
        ("⭐", "account.badge.records_100", "100 Records", false),
        ("🏆", "account.badge.yearly_user", "Yearly User", false),
        ("🌟", "account.badge.milestone", "Milestone Reached", false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.string("account.badges.title", default: "Achievements"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(badges, id: \.0) { badge in
                        VStack(spacing: 4) {
                            Text(badge.0)
                                .font(.system(size: 28))
                                .opacity(badge.3 ? 1.0 : 0.35)

                            Text(localization.string(badge.1, default: badge.2))
                                .font(.system(size: 10))
                                .foregroundColor(badge.3 ? .primary : .secondary)
                        }
                        .frame(width: 60, height: 60)
                        .background(badge.3 ? Color.blue.opacity(0.10) : Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

// MARK: - TopPeopleRowView

struct TopPeopleRowView: View {
    @Environment(AppLocalization.self) private var localization
    private let topPeople = ["A", "B", "C", "D", "E"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localization.string("account.people.title", default: "Most Mentioned People"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: -8) {
                ForEach(topPeople.prefix(5), id: \.self) { name in
                    Circle()
                        .fill(Color.blue.opacity(0.20 + Double.random(in: 0...0.3)))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }

                Spacer()

                Text(localization.string("common.view_all", default: "View All"))
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AccountManagementSheet()
}

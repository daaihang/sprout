import SwiftUI

struct AccountManagementSheet: View {
    private enum Route: Hashable {
        case subscription
        case rate
        case about
        case debug
        case backendInteraction
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppLocalization.self) private var localization
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(AuthSessionManager.self) private var authSession
    @Environment(BiometricLockManager.self) private var biometricLock

    @AppStorage("account.nickname") private var nickname = ""
    @AppStorage("account.daily_prompt_time") private var dailyPromptTime = Date().timeIntervalSince1970
    @AppStorage("account.relationship_reminder_interval") private var reminderInterval = 30

    @State private var showTimePicker = false
    @State private var showReminderPicker = false
    @State private var navigationPath: [Route] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    profileRow

                    nicknameRow

                    LabeledContentWithIcon(
                        icon: loginMethodIcon,
                        tint: loginMethodTint,
                        title: t("account.row.login_method", "Login Method")
                    ) {
                        Text(loginMethodTitle)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink(value: Route.subscription) {
                        LabeledContentWithIcon(icon: "leaf.fill", tint: .green, title: t("account.row.subscription", "Subscription")) {
                            Text(subscriptionDisplayName)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await subscriptionManager.restorePurchases() }
                    } label: {
                        HStack(spacing: 12) {
                            rowIcon("arrow.clockwise.circle.fill", tint: .mint)
                            Text(t("common.restore_purchases", "Restore Purchases"))
                        }
                    }
                    .disabled(subscriptionManager.isLoading)

                    if let upgradeTitle {
                        NavigationLink(value: Route.subscription) {
                            HStack(spacing: 12) {
                                rowIcon("sparkles", tint: .pink)
                                Text(upgradeTitle)
                            }
                        }
                    }
                }

                Section(t("account.section.personal", "Personal Settings")) {
                    Button {
                        showTimePicker = true
                    } label: {
                        SettingsDisclosureRow(
                            icon: "bell.fill",
                            tint: .red,
                            title: t("account.row.daily_prompt", "Daily Prompt Time"),
                            value: pushTimeString
                        )
                    }
                    .foregroundStyle(.primary)

                    Button {
                        showReminderPicker = true
                    } label: {
                        SettingsDisclosureRow(
                            icon: "person.2.fill",
                            tint: .orange,
                            title: t("account.row.relationship_interval", "Relationship Reminder Interval"),
                            value: reminderIntervalString
                        )
                    }
                    .foregroundStyle(.primary)

                    Button {
                        openSystemSettings()
                    } label: {
                        SettingsDisclosureRow(
                            icon: "globe",
                            tint: .blue,
                            title: t("account.row.app_language", "App Language"),
                            value: localization.currentLanguage.nativeDisplayName
                        )
                    }
                    .foregroundStyle(.primary)

                    SettingsStaticValueRow(
                        icon: "moon.fill",
                        tint: .indigo,
                        title: t("account.row.appearance", "Appearance"),
                        value: t("common.follow_system", "Follow System")
                    )
                }

                Section {
                    if biometricLock.isAvailable {
                        Toggle(isOn: biometricBinding) {
                            LabeledContentWithIcon(
                                icon: biometricLock.biometricKind.iconName,
                                tint: .green,
                                title: biometricLock.biometricKind.settingsTitle
                            ) {
                                EmptyView()
                            }
                        }
                    }

                    Button {} label: {
                        HStack(spacing: 12) {
                            rowIcon("square.and.arrow.up", tint: .gray)
                            Text(t("account.row.export_json", "Export Data (JSON)"))
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text(t("account.section.privacy", "Privacy & Security"))
                } footer: {
                    if let errorMessage = biometricLock.lastErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section(t("account.section.about", "About")) {
                    LabeledContentWithIcon(icon: "info.circle.fill", tint: .gray, title: t("account.row.version", "Version")) {
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink(value: Route.rate) {
                        IconTitleRow(icon: "star.fill", tint: .yellow, title: t("account.row.rate", "Rate Sprout"))
                    }

                    NavigationLink(value: Route.about) {
                        IconTitleRow(icon: "info.bubble.fill", tint: .orange, title: t("account.row.feedback", "About"))
                    }
                }

                Section {
                    NavigationLink(value: Route.debug) {
                        IconTitleRow(icon: "ant.fill", tint: .purple, title: t("common.debug", "Debug"))
                    }

                    NavigationLink(value: Route.backendInteraction) {
                        IconTitleRow(icon: "arrow.triangle.branch", tint: .teal, title: t("common.backend.title", "前后端交互"))
                    }
                }

                Section {
                    Button(t("account.row.logout", "Log Out"), role: .destructive) {
                        authSession.signOut()
                        dismiss()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .interactiveDismissDisabled(!navigationPath.isEmpty)
            .navigationTitle(t("account.title", "Account"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .subscription:
                    SubscriptionPaywallView()
                case .rate:
                    Text(t("account.placeholder.rate", "Rating Screen"))
                case .about:
                    Text(t("account.placeholder.feedback", "About Screen"))
                case .debug:
                    DebugPage()
                case .backendInteraction:
                    BackendInteractionDebugView()
                }
            }
            .task {
                await subscriptionManager.refreshCustomerInfo()
                await subscriptionManager.loadOfferings()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel(t("common.close", "Close"))
                }
            }
            .sheet(isPresented: $showTimePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            t("account.sheet.daily_prompt", "Daily Prompt Time"),
                            selection: promptTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
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
            .confirmationDialog(
                t("account.dialog.relationship_title", "Relationship Reminder Interval"),
                isPresented: $showReminderPicker
            ) {
                Button(t("account.reminder.days", "%d days", 7)) { reminderInterval = 7 }
                Button(t("account.reminder.days", "%d days", 14)) { reminderInterval = 14 }
                Button(t("account.reminder.days", "%d days", 30)) { reminderInterval = 30 }
                Button(t("common.cancel", "Cancel"), role: .cancel) {}
            }
        }
    }

    private var profileRow: some View {
        HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayNickname)
                    .font(.headline)

                HStack(spacing: 8) {
                    rowIcon("person.crop.circle.badge.checkmark", tint: .black.opacity(0.75))
                    Text(t("account.row.signed_in", "Signed in"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var biometricBinding: Binding<Bool> {
        Binding(
            get: { biometricLock.isEnabled },
            set: { newValue in
                Task {
                    _ = await biometricLock.setEnabled(newValue)
                }
            }
        )
    }

    private var nicknameRow: some View {
        NavigationLink {
            Form {
                TextField(t("account.row.nickname_placeholder", "Enter nickname"), text: $nickname)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle(t("account.row.nickname", "Nickname"))
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            SettingsDisclosureRow(
                icon: "person.text.rectangle",
                tint: .blue,
                title: t("account.row.nickname", "Nickname"),
                value: displayNickname
            )
        }
    }

    private var promptTimeBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: dailyPromptTime) },
            set: { dailyPromptTime = $0.timeIntervalSince1970 }
        )
    }

    private var displayNickname: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? t("account.profile.default_name", "Sprout User") : trimmed
    }

    private var loginMethodTitle: String {
        switch normalizedLoginMethod {
        case "apple":
            return t("account.login.apple", "Apple")
        case "google":
            return t("account.login.google", "Google")
        case "email":
            return t("account.login.email", "Email")
        default:
            return t("account.row.login_method", "Login Method")
        }
    }

    private var loginMethodIcon: String {
        switch normalizedLoginMethod {
        case "apple":
            return "apple.logo"
        case "google":
            return "globe"
        case "email":
            return "envelope.fill"
        default:
            return "person.badge.key.fill"
        }
    }

    private var normalizedLoginMethod: String {
        let mode = authSession.currentSession?.mode.lowercased() ?? ""
        switch mode {
        case "development_stub", "apple":
            return "apple"
        case "google":
            return "google"
        case "email":
            return "email"
        default:
            return ""
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var loginMethodTint: Color {
        switch normalizedLoginMethod {
        case "apple":
            return .black.opacity(0.75)
        case "google":
            return .blue
        case "email":
            return .green
        default:
            return .gray
        }
    }

    private var pushTimeString: String {
        localization.shortTimeString(from: Date(timeIntervalSince1970: dailyPromptTime))
    }

    private var reminderIntervalString: String {
        t("account.reminder.days", "%d days", reminderInterval)
    }

    private var subscriptionDisplayName: String {
        if subscriptionManager.isSubscribed {
            if let packageKind = subscriptionManager.currentPackageKind {
                return planName(for: packageKind)
            }
            return t("subscription.status.active_generic", "Subscription active")
        }
        return t("account.profile.free", "Free")
    }

    private var upgradeTitle: String? {
        if subscriptionManager.isSubscribed {
            return nil
        }

        if let yearly = subscriptionManager.summary(for: .yearly) {
            return t("subscription.status.yearly_price", "Yearly %@%@", yearly.price, periodLabel(for: .yearly))
        }

        if let monthly = subscriptionManager.summary(for: .monthly) {
            return t("subscription.status.monthly_price", "Monthly %@%@", monthly.price, periodLabel(for: .monthly))
        }

        return t("subscription.status.upgrade", "Upgrade")
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

    private func rowIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

private struct LabeledContentWithIcon<Content: View>: View {
    let icon: String
    let tint: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)

            Spacer()

            content()
        }
    }
}

private struct IconTitleRow: View {
    let icon: String
    let tint: Color
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)
        }
    }
}

private struct SettingsDisclosureRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SettingsStaticValueRow: View {
    let icon: String
    let tint: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(title)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    AccountManagementSheet()
}

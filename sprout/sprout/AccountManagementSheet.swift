import SwiftUI

struct AccountManagementSheet: View {
    private enum Route: Hashable {
        case subscription
        case rate
        case about
        case reflectionInbox
        case debug
        case backendInteraction
        case dailyPrompt
        case appLanguage
        case appearance
        case exportData
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

    @State private var navigationPath: [Route] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    profileRow

                    nicknameRow

                    rowContent(
                        icon: loginMethodIcon,
                        tint: loginMethodTint,
                        title: t("account.row.login_method", "Login Method"),
                        value: loginMethodTitle
                    )
                    .foregroundStyle(.primary)

                    NavigationLink(value: Route.subscription) {
                        rowContent(
                            icon: "leaf.fill",
                            tint: .green,
                            title: t("account.row.subscription", "Subscription"),
                            value: subscriptionDisplayName
                        )
                    }
                }

                Section(t("account.section.personal", "Personal Settings")) {
                    NavigationLink(value: Route.dailyPrompt) {
                        rowContent(
                            icon: "bell.fill",
                            tint: .red,
                            title: t("account.row.daily_prompt", "Daily Prompt Time"),
                            value: pushTimeString
                        )
                    }

                    Menu {
                        Button(t("account.reminder.days", "%d days", 7)) { reminderInterval = 7 }
                        Button(t("account.reminder.days", "%d days", 14)) { reminderInterval = 14 }
                        Button(t("account.reminder.days", "%d days", 30)) { reminderInterval = 30 }
                    } label: {
                        rowContent(
                            icon: "person.2.fill",
                            tint: .orange,
                            title: t("account.row.relationship_interval", "Relationship Reminder Interval"),
                            value: reminderIntervalString
                        )
                    }
                    .foregroundStyle(.primary)

                    NavigationLink(value: Route.appLanguage) {
                        rowContent(
                            icon: "globe",
                            tint: .blue,
                            title: t("account.row.app_language", "App Language"),
                            value: localization.currentLanguage.nativeDisplayName
                        )
                    }

                    NavigationLink(value: Route.appearance) {
                        rowContent(
                            icon: "moon.fill",
                            tint: .indigo,
                            title: t("account.row.appearance", "Appearance"),
                            value: t("common.follow_system", "Follow System")
                        )
                    }
                }

                Section {
                    if biometricLock.isAvailable {
                        Toggle(isOn: biometricBinding) {
                            rowTitleContent(
                                icon: biometricLock.biometricKind.iconName,
                                tint: .green,
                                title: biometricLock.biometricKind.settingsTitle
                            )
                        }
                    }

                    NavigationLink(value: Route.exportData) {
                        rowTitleContent(
                            icon: "square.and.arrow.up",
                            tint: .gray,
                            title: t("account.row.export_json", "Export Data (JSON)")
                        )
                    }
                } header: {
                    Text(t("account.section.privacy", "Privacy & Security"))
                } footer: {
                    if let errorMessage = biometricLock.lastErrorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section(t("account.section.about", "About")) {
                    rowContent(
                        icon: "info.circle.fill",
                        tint: .gray,
                        title: t("account.row.version", "Version"),
                        value: appVersion
                    )
                    .foregroundStyle(.primary)

                    NavigationLink(value: Route.rate) {
                        rowTitleContent(
                            icon: "star.fill",
                            tint: .yellow,
                            title: t("account.row.rate", "Rate Sprout")
                        )
                    }

                    NavigationLink(value: Route.about) {
                        rowTitleContent(
                            icon: "info.bubble.fill",
                            tint: .orange,
                            title: t("account.row.feedback", "About")
                        )
                    }
                }

                Section {
                    NavigationLink(value: Route.reflectionInbox) {
                        rowTitleContent(
                            icon: "tray.full",
                            tint: .green,
                            title: t("account.row.reflection_inbox", "Reflection Inbox")
                        )
                    }

                    NavigationLink(value: Route.debug) {
                        rowTitleContent(
                            icon: "ant.fill",
                            tint: .purple,
                            title: t("common.debug", "Debug")
                        )
                    }

                    NavigationLink(value: Route.backendInteraction) {
                        rowTitleContent(
                            icon: "arrow.triangle.branch",
                            tint: .teal,
                            title: t("common.backend.title", "前后端交互")
                        )
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
                case .reflectionInbox:
                    ReflectionInboxView()
                case .debug:
                    DebugPage()
                case .backendInteraction:
                    BackendInteractionDebugView()
                case .dailyPrompt:
                    dailyPromptSettingsView
                case .appLanguage:
                    appLanguageSettingsView
                case .appearance:
                    appearanceSettingsView
                case .exportData:
                    exportDataSettingsView
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
        }
    }

    @ViewBuilder
    private func rowContent(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, tint: tint)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func rowTitleContent(icon: String, tint: Color, title: String) -> some View {
        HStack(spacing: 12) {
            rowIcon(icon, tint: tint)
            Text(title)
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
            rowContent(
                icon: "person.text.rectangle",
                tint: .blue,
                title: t("account.row.nickname", "Nickname"),
                value: displayNickname
            )
        }
    }

    private var dailyPromptSettingsView: some View {
        Form {
            DatePicker(
                t("account.sheet.daily_prompt", "Daily Prompt Time"),
                selection: promptTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
        }
        .navigationTitle(t("account.sheet.daily_prompt", "Daily Prompt Time"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appLanguageSettingsView: some View {
        List {
            Section {
                rowContent(
                    icon: "globe",
                    tint: .blue,
                    title: t("account.row.app_language", "App Language"),
                    value: localization.currentLanguage.nativeDisplayName
                )
            }

            Section {
                Button {
                    openSystemSettings()
                } label: {
                    Text(t("account.language.open_settings", "Open System Settings"))
                }
            } footer: {
                Text(t("account.language.footer", "Sprout currently follows the language configured in iOS Settings."))
            }
        }
        .navigationTitle(t("account.row.app_language", "App Language"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearanceSettingsView: some View {
        List {
            Section {
                rowContent(
                    icon: "moon.fill",
                    tint: .indigo,
                    title: t("account.row.appearance", "Appearance"),
                    value: t("common.follow_system", "Follow System")
                )
            } footer: {
                Text(t("account.appearance.footer", "Appearance currently follows the system setting."))
            }
        }
        .navigationTitle(t("account.row.appearance", "Appearance"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var exportDataSettingsView: some View {
        List {
            Section {
                Button(t("account.row.export_json", "Export Data (JSON)")) {}
            } footer: {
                Text(t("account.export.footer", "Export is not implemented yet. This entry keeps the row in a native navigation flow."))
            }
        }
        .navigationTitle(t("account.row.export_json", "Export Data (JSON)"))
        .navigationBarTitleDisplayMode(.inline)
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

#Preview {
    AccountManagementSheet()
}

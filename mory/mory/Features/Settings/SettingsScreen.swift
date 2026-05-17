import SwiftUI

struct SettingsScreen: View {
    let authManager: AuthSessionManager?
    let runtimeEnvironment: AppRuntimeEnvironment

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SettingsRoute.visibleRoutes(allowsDebugTools: runtimeEnvironment.allowsDebugTools)) { route in
                        NavigationLink {
                            destination(for: route)
                        } label: {
                            MoryHubRow(
                                title: LocalizedStringKey(route.titleKey),
                                subtitle: LocalizedStringKey(route.subtitleKey),
                                systemImage: route.systemImage
                            )
                        }
                    }
                }

                Section("settings.runtime.section") {
                    LabeledContent("settings.runtime.environment", value: runtimeEnvironment.label)
                    LabeledContent("settings.runtime.version", value: "\(runtimeEnvironment.version) (\(runtimeEnvironment.buildNumber))")
                }
            }
            .navigationTitle("settings.nav.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .account:
            SettingsAccountSection(authManager: authManager)
        case .permissions:
            SettingsPlaceholderSection(
                title: "settings.permissions.title",
                message: "settings.permissions.body",
                systemImage: "hand.raised"
            )
        case .privacy:
            SettingsPlaceholderSection(
                title: "settings.privacy.title",
                message: "settings.privacy.body",
                systemImage: "lock.shield"
            )
        case .capturePreferences:
            SettingsPlaceholderSection(
                title: "settings.capture.title",
                message: "settings.capture.body",
                systemImage: "slider.horizontal.3"
            )
        case .appearanceLanguage:
            SettingsPlaceholderSection(
                title: "settings.appearance.title",
                message: "settings.appearance.body",
                systemImage: "textformat.size"
            )
        case .diagnostics:
            if runtimeEnvironment.allowsDebugTools {
                DebugDiagnosticsView(
                    authManager: authManager,
                    runtimeEnvironment: runtimeEnvironment
                )
            } else {
                SettingsPlaceholderSection(
                    title: "settings.diagnostics.title",
                    message: "settings.diagnostics.unavailable",
                    systemImage: "stethoscope"
                )
            }
        }
    }
}

private struct SettingsAccountSection: View {
    let authManager: AuthSessionManager?

    @State private var diagnostics: AuthDiagnosticsSnapshot?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("settings.account.title") {
                if let diagnostics {
                    LabeledContent("settings.account.state", value: diagnostics.state)
                    LabeledContent("settings.account.userID", value: diagnostics.userID ?? String(localized: "settings.account.localUser"))
                    LabeledContent("settings.account.guest", value: diagnostics.isGuest ? String(localized: "common.yes") : String(localized: "common.no"))
                } else {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task {
                        await authManager?.signOut()
                    }
                } label: {
                    Label("settings.account.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("settings.account.title")
        .task {
            await load()
        }
    }

    @MainActor
    private func load() async {
        guard let authManager else {
            errorMessage = String(localized: "settings.account.noManager")
            return
        }
        diagnostics = await authManager.fetchDiagnostics()
        errorMessage = nil
    }
}

private struct SettingsPlaceholderSection: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .navigationTitle(title)
    }
}

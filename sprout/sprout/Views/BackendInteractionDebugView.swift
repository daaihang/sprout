import AuthenticationServices
import SwiftUI

struct BackendInteractionDebugView: View {
    @Environment(AppLocalization.self) private var localization
    @Environment(AuthSessionManager.self) private var authSession
    @Environment(InstallExperienceStore.self) private var installExperience
    @State private var currentNonce = ""

    var body: some View {
        List {
            Section(t("common.backend.section.connection", "当前连接")) {
                debugRow(title: t("common.backend.configured_base_url", "配置中的 Base URL"), value: MoryConfig.configuredAPIBaseURL ?? "-")
                debugRow(title: t("common.backend.base_url", "生效 Base URL"), value: MoryConfig.apiBaseURL)
                debugRow(title: t("common.backend.host", "主机名"), value: backendHost)
                debugRow(title: t("common.backend.environment", "运行环境"), value: currentEnvironment)
                debugRow(title: t("common.backend.auth_state", "登录状态"), value: authState)
                debugRow(title: t("common.backend.last_error", "最近错误"), value: authSession.errorMessage ?? "-")
            }

            Section(t("common.backend.section.session", "会话与鉴权")) {
                debugRow(title: t("common.backend.user_id", "User ID"), value: authSession.currentSession?.userID ?? "-")
                debugRow(title: t("common.backend.tier", "订阅层级"), value: authSession.currentSession?.tier ?? "-")
                debugRow(title: t("common.backend.mode", "登录模式"), value: authSession.currentSession?.mode ?? "-")
                debugRow(title: t("common.backend.expires_at", "过期时间"), value: format(date: authSession.currentSession?.expiresAt))
                debugRow(title: t("common.backend.is_expired", "是否已过期"), value: boolText(authSession.currentSession?.isExpired ?? false))
                debugRow(title: "Onboarding Complete", value: boolText(authSession.currentSession?.hasCompletedOnboarding ?? false))

                Button(t("common.backend.action.refresh_session", "测试 Refresh")) {
                    Task { await authSession.refreshSession() }
                }
                .disabled(authSession.currentSession == nil || authSession.currentSession?.mode == "development_stub")
            }

            Section("Onboarding Debug") {
                debugRow(title: "Has Seen Welcome", value: boolText(installExperience.hasSeenWelcome))
                debugRow(title: "Force Show Welcome", value: boolText(installExperience.forceShowWelcome))
                debugRow(title: "Force Signed-In Onboarding", value: boolText(installExperience.forceRequireSignedInOnboarding))

                Toggle("Force Show Welcome", isOn: Binding(
                    get: { installExperience.forceShowWelcome },
                    set: { installExperience.setForceShowWelcome($0) }
                ))

                Toggle("Force Signed-In Onboarding", isOn: Binding(
                    get: { installExperience.forceRequireSignedInOnboarding },
                    set: { installExperience.setForceRequireSignedInOnboarding($0) }
                ))

                Button("Mark Welcome As Seen") {
                    installExperience.markWelcomeSeen()
                }

                Button("Reset Welcome State") {
                    installExperience.resetWelcome()
                }
            }

            Section(t("common.backend.section.health", "后端健康检查")) {
                if let health = authSession.lastHealthCheck {
                    debugRow(title: t("common.backend.checked_at", "检查时间"), value: format(date: health.checkedAt))
                    debugRow(title: t("common.backend.status_code", "状态码"), value: health.statusCode.map(String.init) ?? "-")
                    debugRow(title: t("common.backend.duration", "耗时"), value: health.durationText)
                    debugRow(title: t("common.backend.response_body", "响应 Body"), value: health.responseBody ?? "-", multiline: true)
                    debugRow(title: t("common.backend.error", "错误"), value: health.errorDescription ?? "-", multiline: true)
                } else {
                    Text(t("common.backend.no_health_check", "尚未执行健康检查。"))
                        .foregroundStyle(.secondary)
                }

                Button(t("common.backend.action.run_health", "执行健康检查")) {
                    Task { await authSession.runHealthCheck() }
                }
            }

            Section(t("common.backend.section.apple", "Apple 登录调试")) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleNonce.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(authSession.isAuthenticating)

                debugRow(title: t("common.backend.identity_token", "Identity Token"), value: authSession.lastAppleIdentityToken ?? "-", multiline: true)
                debugRow(title: t("common.backend.raw_nonce", "原始 Nonce"), value: authSession.lastAppleRawNonce ?? "-", multiline: true)
                debugRow(title: t("common.backend.hashed_nonce", "哈希 Nonce"), value: authSession.lastAppleHashedNonce ?? "-", multiline: true)

                requestRecordSection(record: authSession.lastAuthRequest, emptyText: t("common.backend.no_auth_request", "还没有记录到 Apple 登录请求。"))
            }

            Section(t("common.backend.section.refresh", "Refresh 请求调试")) {
                requestRecordSection(record: authSession.lastRefreshRequest, emptyText: t("common.backend.no_refresh_request", "还没有记录到 Refresh 请求。"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(t("common.backend.title", "前后端交互"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await authSession.runHealthCheck()
        }
    }

    @ViewBuilder
    private func requestRecordSection(record: AuthSessionManager.RequestRecord?, emptyText: String) -> some View {
        if let record {
            debugRow(title: t("common.backend.url", "URL"), value: record.url, multiline: true)
            debugRow(title: t("common.backend.method", "Method"), value: record.method)
            debugRow(title: t("common.backend.started_at", "开始时间"), value: format(date: record.startedAt))
            debugRow(title: t("common.backend.completed_at", "结束时间"), value: format(date: record.completedAt))
            debugRow(title: t("common.backend.status_code", "状态码"), value: record.statusCode.map(String.init) ?? "-")
            debugRow(title: t("common.backend.duration", "耗时"), value: record.durationText)
            debugRow(title: t("common.backend.request_headers", "请求头"), value: dictionaryText(record.requestHeaders), multiline: true)
            debugRow(title: t("common.backend.request_body", "请求 Body"), value: record.requestBody ?? "-", multiline: true)
            debugRow(title: t("common.backend.response_headers", "响应头"), value: dictionaryText(record.responseHeaders), multiline: true)
            debugRow(title: t("common.backend.response_body", "响应 Body"), value: record.responseBody ?? "-", multiline: true)
            debugRow(title: t("common.backend.error", "错误"), value: record.errorDescription ?? "-", multiline: true)
        } else {
            Text(emptyText)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func debugRow(title: String, value: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(multiline ? nil : 2)
        }
        .padding(.vertical, 2)
    }

    private var currentEnvironment: String {
        #if targetEnvironment(simulator)
        return t("common.backend.simulator", "模拟器")
        #else
        return t("common.backend.device", "真机")
        #endif
    }

    private var authState: String {
        switch authSession.state {
        case .loading:
            return t("common.backend.auth_loading", "加载中")
        case .signedOut:
            return t("common.backend.auth_signed_out", "未登录")
        case let .signedIn(session):
            return "\(t("common.backend.auth_signed_in", "已登录")) (\(session.mode))"
        }
    }

    private var backendHost: String {
        URL(string: MoryConfig.apiBaseURL)?.host ?? "-"
    }

    private func boolText(_ value: Bool) -> String {
        value ? t("common.backend.yes", "是") : t("common.backend.no", "否")
    }

    private func format(date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private func dictionaryText(_ value: [String: String]) -> String {
        guard !value.isEmpty else { return "-" }
        return value
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                authSession.errorMessage = AuthError.missingIdentityToken.localizedDescription
                return
            }

            Task {
                await authSession.signInWithApple(
                    payload: .init(identityToken: identityToken, rawNonce: currentNonce)
                )
            }
        case let .failure(error):
            authSession.errorMessage = error.localizedDescription
        }
    }

    private func t(_ key: String, _ defaultValue: String, _ arguments: CVarArg...) -> String {
        localization.string(key, default: defaultValue, arguments: arguments)
    }
}

#Preview {
    NavigationStack {
        BackendInteractionDebugView()
    }
}

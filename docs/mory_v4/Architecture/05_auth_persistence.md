# 05. Auth Persistence

## 1. 问题

v3 实现了 Apple Sign In，但 token 没有持久化。每次冷启动都需要重新登录。

## 2. 现有架构

```
SignInView → AppleAuthService → 服务端验证 → JWT
                                     ↓
                              KeychainCredentialStore（已有，但未正确使用）
```

`KeychainCredentialStore` 已经存在，有 `save()` 和 `load()` 方法。问题在于：

1. App 启动时没有检查 Keychain 中是否已有有效 token
2. Token 过期后没有刷新逻辑
3. 登录状态没有全局管理

## 3. v4 方案

### 3.1 启动流程

```
App 启动
  → KeychainCredentialStore.load()
  → 如果有 token:
      → 验证是否过期
      → 如果未过期: 直接进入主界面
      → 如果过期: 尝试 refresh
          → refresh 成功: 进入主界面
          → refresh 失败: 显示登录页
  → 如果无 token:
      → 显示登录页
```

### 3.2 AuthSessionManager

```swift
@MainActor
@Observable
final class AuthSessionManager {
    enum State {
        case loading           // 启动检查中
        case authenticated     // 已登录
        case unauthenticated   // 需要登录
    }

    private(set) var state: State = .loading
    private let credentialStore: KeychainCredentialStore
    private let apiClient: MoryAPIClient

    func checkSession() async {
        guard let credential = credentialStore.load() else {
            state = .unauthenticated
            return
        }

        if credential.isExpired {
            do {
                let refreshed = try await apiClient.refreshToken(credential.refreshToken)
                credentialStore.save(refreshed)
                state = .authenticated
            } catch {
                credentialStore.clear()
                state = .unauthenticated
            }
        } else {
            state = .authenticated
        }
    }

    func signIn(with appleCredential: ASAuthorizationAppleIDCredential) async throws {
        let credential = try await apiClient.authenticateWithApple(appleCredential)
        credentialStore.save(credential)
        state = .authenticated
    }

    func signOut() {
        credentialStore.clear()
        state = .unauthenticated
    }
}
```

### 3.3 MoryApp 入口修改

```swift
@main
struct MoryApp: App {
    @State private var authManager = AuthSessionManager()

    var body: some Scene {
        WindowGroup {
            Group {
                switch authManager.state {
                case .loading:
                    ProgressView()
                case .authenticated:
                    MoryRootView()
                case .unauthenticated:
                    SignInView()
                }
            }
            .task {
                await authManager.checkSession()
            }
        }
    }
}
```

### 3.4 Credential 模型

```swift
struct AuthCredential: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: String

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-300) // 提前 5 分钟视为过期
    }
}
```

### 3.5 KeychainCredentialStore 改造

现有的 `KeychainCredentialStore` 需要确认：

1. `save()` 存储完整的 `AuthCredential`（含 refreshToken + expiresAt）
2. `load()` 返回 `AuthCredential?`
3. `clear()` 删除所有凭证
4. 使用 `kSecAttrAccessible = kSecAttrAccessibleAfterFirstUnlock` 确保后台可访问

## 4. Guest 模式

当前有 "Continue as Guest" 按钮。Guest 模式下：

- 不调用服务端 API
- AI 分析不可用
- 其余本地功能正常

Guest 模式的 token 是一个本地生成的占位 credential，`isGuest = true`。

## 5. 服务端配合

服务端需要：

1. `/api/auth/refresh` endpoint — 接受 refreshToken，返回新的 accessToken
2. refreshToken 有效期 ≥ 30 天
3. accessToken 有效期 = 1 小时

如果服务端已有 `dev_auth` 模式，确保开发环境不强制 token 过期。

## 6. 验收标准

| 场景 | 预期行为 |
|------|---------|
| 首次安装后打开 | 显示登录页 |
| Apple 登录成功后关闭 app | 重新打开直接进入主界面 |
| Token 过期后打开 | 自动 refresh，用户无感 |
| Refresh token 也过期 | 显示登录页，需要重新登录 |
| 用户主动退出 | 清除 Keychain，显示登录页 |
| 连续 7 天每天冷启动 | 0 次需要重新登录 |

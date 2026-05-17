# 06. Account Settings Data Model

## 1. Goal

Settings needs local state that can later sync without blocking v5.

## 2. Domain Model

Recommended model:

```swift
struct UserSettingsPreference: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var syncKey: String
    var schemaVersion: Int
    var updatedAt: Date
    var appearanceMode: AppearanceMode
    var voiceLanguageIdentifier: String?
    var linkAutoDetectEnabled: Bool
    var defaultContextSelection: ContextSelectionPreference
    var insightFrequency: InsightFrequency
    var promptTone: PromptTonePreference
}
```

Supporting enums:

- AppearanceMode: system, light, dark.
- ContextSelectionPreference: allAvailable, locationWeatherOnly, manual.
- InsightFrequency: low, balanced, high.
- PromptTonePreference: concise, balanced, reflective.

## 3. Store Model

SwiftData store:

- `UserSettingsPreferenceStore`
- Unique syncKey.
- Raw values for enums.
- updatedAt.
- schemaVersion.

## 4. Account Snapshot

Settings should consume:

```swift
struct AccountSettingsSnapshot {
    var authState: AuthState
    var loginMethod: LoginMethod
    var userID: String?
    var email: String?
    var displayName: String?
    var settings: UserSettingsPreference
    var permissions: PermissionMatrixSnapshot
    var runtime: RuntimeSupportSnapshot
}
```

## 5. Permission Snapshot

Fields:

- Location.
- Photos.
- Microphone.
- Speech.
- Music.
- Weather availability.

Each permission:

- Status.
- Can request.
- Can open settings.
- Explanation string key.

## 6. Repository API

Recommended protocol additions:

- `fetchUserSettingsPreference()`
- `saveUserSettingsPreference(_:)`
- `fetchAccountSettingsSnapshot()`
- `signOut()`
- `exportLocalData()`
- `deleteAllLocalData(confirm:)`

Sign out likely lives with auth manager, but Settings should have a single view model that coordinates auth and repository.

## 7. Public vs Internal Settings

Public:

- Account.
- Permissions.
- Privacy.
- Capture preferences.
- Language.
- Appearance.
- Data.

Internal:

- Environment.
- Auth raw diagnostics.
- Server health.
- Quality lab.
- Home board rules.
- Storage integrity.

## 8. Acceptance Criteria

- Settings state persists.
- Settings can be read without network.
- Permission matrix loads quickly.
- Internal diagnostics are gated.
- Model has sync-ready metadata.


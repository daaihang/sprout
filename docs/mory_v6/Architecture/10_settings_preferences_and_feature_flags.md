# 10. Settings, Preferences, And Feature Flags

## 1. Goal

V6 introduces active intelligence. It must be controllable from day one.

Settings and feature flags are not polish; they are part of the architecture.

## 2. Preference Domains

Add structured preferences for:

- Local AI.
- Cloud AI.
- Voice refinement.
- Semantic search indexing.
- Home suggestions.
- Daily questions.
- Notifications.
- Sensitive topics.
- Debug/quality mode.

## 3. Suggested Domain Model

```swift
struct IntelligencePreferences: Codable, Hashable, Sendable {
    var localIntelligenceEnabled: Bool
    var cloudIntelligenceEnabled: Bool
    var voiceRefinementEnabled: Bool
    var semanticSearchEnabled: Bool
    var homeSuggestionsEnabled: Bool
    var dailyQuestionsEnabled: Bool
    var notificationPreferences: NotificationPreferences
    var questionTone: DailyQuestionTone
    var sensitiveTopicPolicy: SensitiveTopicPolicy
    var updatedAt: Date
}
```

```swift
struct NotificationPreferences: Codable, Hashable, Sendable {
    var enabled: Bool
    var backgroundDoneEnabled: Bool
    var dailyQuestionEnabled: Bool
    var repeatedThemeEnabled: Bool
    var stageFormingEnabled: Bool
    var revisitEnabled: Bool
    var maxPerDay: Int
    var quietHoursStart: DateComponents?
    var quietHoursEnd: DateComponents?
    var richPreviewsEnabled: Bool
}
```

## 4. Defaults

Recommended alpha defaults:

| Setting | Default | Reason |
| --- | --- | --- |
| Local intelligence | on | Core V6 behavior |
| Cloud intelligence | off or ask | Privacy-sensitive |
| Voice refinement | ask first run | It changes visible text |
| Semantic indexing | on if system available | Local capability |
| Home suggestions | on | Main V6 surface |
| Daily questions | off until enabled or soft prompt | Notification sensitivity |
| Notifications | off until permission | Platform requirement |
| Rich previews | off | Privacy |
| Sensitive topic notifications | off | Safety |

## 5. Feature Flags

Add flags separate from user preferences.

Examples:

```swift
struct V6FeatureFlags: Codable, Hashable, Sendable {
    var intelligenceJobs: Bool
    var entityProfiles: Bool
    var clarificationQuestions: Bool
    var homeGrid: Bool
    var semanticSearch: Bool
    var dailyQuestions: Bool
    var localNotifications: Bool
    var cloudQuestionSuggestions: Bool
    var cloudChapterSuggestions: Bool
    var multimediaViews: Bool
}
```

Flags are for rollout and debugging. Preferences are for the user.

## 6. Settings UI

Use native grouped settings.

Sections:

1. Intelligence
2. Voice And Writing
3. Search
4. Home Suggestions
5. Daily Questions
6. Notifications
7. Privacy
8. Developer Diagnostics

Do not overload Account settings with every V6 toggle. Use nested detail pages where needed.

## 7. Copy Requirements

Examples:

Local AI:

```text
Mory can organize lightweight signals on this device, such as recurring people, topics, and search indexes.
```

Cloud AI:

```text
When enabled, Mory may send selected snippets to cloud AI for deeper reflection, transcript cleanup, or chapter suggestions.
```

Voice refinement:

```text
Clean up voice transcripts by adding punctuation and removing repeated filler words. Your original audio remains saved.
```

Rich previews:

```text
Show memory details in notifications. Turn this off to keep notification text generic.
```

## 8. Permission Flow

Notification permission should be requested only after:

- User enables notifications.
- User accepts daily questions.
- User turns on a notification type that needs delivery.

Search indexing does not need a system permission prompt, but the setting should explain local indexing.

Cloud AI should require an explicit setting or per-action confirmation before sending private snippets.

## 9. Persistence

Store preferences locally in SwiftData.

Suggested store:

```text
IntelligencePreferenceStore
  id
  payloadJSON
  updatedAt
  schemaVersion
```

Reason:

- Avoid migration churn while preference shape evolves.
- Keep typed domain model in code.
- Allow future CloudKit sync if approved.

## 10. Server Sync

Only sync notification-related preferences if remote push is enabled.

Do not sync:

- Full home layout.
- Full graph.
- Full memory content.

Possible sync:

- Device token.
- Locale.
- Time zone.
- Notification preferences.
- Rich preview preference.
- Quota tier.

## 11. Debug Controls

Developer diagnostics should include:

- Run pending intelligence jobs.
- Clear failed jobs.
- Rebuild Spotlight index.
- Generate sample question.
- Show feature flags.
- Export redacted intelligence logs.

Keep debug controls out of normal user flows.

## 12. Testing

Unit tests:

- Defaults decode.
- Preference migrations.
- Notification policy with quiet hours.
- Rich preview disabled path.
- Cloud AI disabled path.

UI tests:

- Settings toggles persist.
- Notification permission prompt only appears after opt-in.
- Cloud AI copy appears before cloud call.

## 13. Acceptance Criteria

- V6 features can be enabled/disabled without code removal.
- User preferences are distinct from rollout flags.
- Notification frequency and preview privacy are controllable.
- Cloud AI cannot run when disabled.
- Settings copy is understandable without reading docs.

# 15. iOS Capability Matrix

## 1. Purpose

v7 needs an iOS-native orchestration plan. This matrix defines which Apple mechanisms are useful for Mory, what they can do, what they cannot do, and how they combine.

Every item must be verified against the active SDK and gated by OS availability during implementation.

## 2. Background Tasks

| Mechanism | Use in Mory | Limit |
| --- | --- | --- |
| `BGAppRefreshTask` | daily question refresh, notification intent fetch, preference sync | best effort, short runtime |
| `BGProcessingTask` | profile recompute, deferred intelligence jobs, index rebuild | not real-time, system scheduled |
| launch recovery | catch up missed work on app open | foreground-dependent |
| server scheduled job | cloud reflection/notification candidate generation | needs server and APNs writeback |

Rules:

- background jobs are idempotent,
- each job writes progress and failure reason,
- every scheduled task has launch recovery fallback,
- no feature assumes exact wake-up time.

## 3. Background Networking

| Mechanism | Use in Mory | Notes |
| --- | --- | --- |
| background `URLSession` upload | context pack / audio / large payload upload | delegate handles completion |
| background `URLSession` download | AI result / sync payload | writeback must be idempotent |
| foreground session | immediate capture save/analyze | not durable after suspension |

Use background sessions for deferred AI work, not for tiny foreground-only requests.

## 4. Notifications

| Mechanism | Use in Mory | Notes |
| --- | --- | --- |
| `UNUserNotificationCenter` local notification | daily question, reminder, local reflection | app controls content locally |
| APNs alert push | cloud analysis ready, server-selected prompt | server controls timing better than BGTask |
| silent push | fetch remote state / wake app opportunistically | throttled, best effort |
| notification actions | answer/snooze/dismiss/writeback | must persist interaction event |

Preview policy:

- relationship-sensitive: redacted or in-app only,
- health/mood-sensitive: redacted or in-app only,
- generic reminder: safe local preview.

## 5. App-External Capture

| Mechanism | Use in Mory | Output |
| --- | --- | --- |
| App Intents | quick text/link capture through Shortcuts/Siri phrases | `ExternalCaptureInboxItem` -> `CaptureDraft` |
| Shortcuts/Siri | user-triggered record flow | `CaptureDraft` |
| Share Sheet | links, screenshots, selected text, images | `ExternalCaptureInboxItem` -> artifacts + context evidence |
| widgets/control surfaces | lightweight capture entry | draft or reminder |

All external capture must reuse the normal repository save path.

## 6. Journaling Suggestions

| Capability | Mory use |
| --- | --- |
| user-selected suggestion | create context-rich draft |
| location/media/workout/contact assets | context evidence |
| reflection prompt | prompt evidence |
| StateOfMind | affect evidence |

Limits:

- not automatic background ingestion,
- not access to all Journal app data,
- not a voice tone detector,
- user must choose what to share.

## 7. Front-Facing Local Processing

| Framework | Use |
| --- | --- |
| Speech | transcript, uncertainty, optional local language path |
| AVFoundation | audio/camera capture |
| Vision | image labels, object/document clues |
| VisionKit | OCR/document extraction |
| NaturalLanguage | language/entity/topic hints |
| Core ML | optional local affect/tone classifier |

Local processing produces evidence with confidence, not trusted final facts.

## 8. Recommended Composition

Daily question:

```text
BGAppRefreshTask
  -> build lightweight candidate
  -> policy gate
  -> local notification
  -> interaction writeback
  -> context pack negative/positive signal
```

Cloud analysis ready:

```text
Capture save
  -> enqueue server job or background upload
  -> server computes
  -> APNs safe preview
  -> app fetches result
  -> proposal mapping
```

System suggestion capture:

```text
User opens Journaling Suggestions picker
  -> selects suggestion
  -> Mory maps assets to evidence
  -> normal CaptureDraft save
  -> AnalyzeContextPack includes provenance
```

Implementation note:

- On device builds with `JournalingSuggestions.framework`, the app presents the Apple picker and maps selected assets.
- On Simulator/non-framework builds, the native fallback form remains visible so development and tests do not depend on entitlement-only APIs.
- No `JournalingMemory` type exists; every suggestion becomes a normal draft with provenance.
- Share Extension uses the official extension confirmation flow: the extension previews the payload, the user taps Add to Mory, and a V2-only envelope is written to the App Group inbox. Opening the main app is user-initiated best effort, not an automatic success dependency.
- Platform Capture Diagnostics must expose runtime readiness for Journaling availability, App Group defaults/container, Share Extension bundling, App Intents metadata, external inbox counts, and manual physical-device checks.

## 9. Acceptance Criteria

- Every iOS capability has fallback behavior.
- Background jobs never assume exact timing.
- Silent push is treated as opportunistic.
- PushKit is not used for non-VoIP work.
- External capture produces normal domain data.
- Settings and Debug include a platform-capture diagnostic surface before physical-device validation starts.

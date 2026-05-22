# 06. Background AI Notification Orchestration

## 1. Problem

Current intelligence preparation is foreground-biased: launch recovery and Home refresh can prepare daily questions and notifications, but Mory does not yet have a complete iOS background scheduler + cloud push + local fallback loop.

v7 needs to make the app feel alive while respecting iOS limits:

- no unlimited background runtime,
- no precise guaranteed background schedule,
- no silent reading of private system data,
- all sensitive prompts must be policy-gated.

## 2. Architecture

```text
Foreground Capture / Launch
  -> enqueue intelligence jobs
  -> immediate local analysis where possible

BGAppRefreshTask
  -> fetch remote state
  -> prepare daily question candidate
  -> schedule local notification if policy allows

BGProcessingTask
  -> process deferred analysis jobs
  -> refresh profiles/arcs/reflections
  -> rebuild indexes
  -> compact stale context

Background URLSession
  -> durable upload/download for longer AI/network payloads

Server Jobs + APNs
  -> cloud analysis complete
  -> push ready intent
  -> app writeback on interaction/open

App Intents / Shortcuts / Share
  -> app-external capture trigger
  -> create memory draft with system context
```

This layer is implemented with `BGTaskScheduler`, `UNUserNotificationCenter`, APNs, background `URLSession`, App Intents, and local recovery. It must be designed as best-effort orchestration, not as precise or unlimited background execution.

## 3. Background Tasks

### BGAppRefreshTask

Use for light work:

- daily question refresh,
- notification intent fetch,
- preference sync,
- small context precomputation.

Rules:

- short execution budget,
- idempotent,
- safe to skip,
- always reschedule before completion.

### BGProcessingTask

Use for heavier work:

- profile portrait refresh,
- deferred AI job packaging,
- search/Spotlight rebuild,
- recompute after merge/split,
- cache cleanup.

Rules:

- requires network only when needed,
- can require external power for large jobs,
- time-boxed with progress checkpoints.

## 4. Background URLSession

Use when AI/network work should survive app suspension:

- upload context pack,
- download cloud analysis result,
- sync APNs preference state,
- fetch remote notification payload details.

Never rely on a normal foreground `URLSession` for critical deferred work.

## 5. Notifications

### Local Notifications

Use when app can prepare content locally:

- daily question,
- evening reflection,
- memory reminder,
- locally detected context revisit.

### APNs

Use when server has the authoritative event:

- cloud analysis completed,
- reflection ready,
- queued remote prompt,
- cross-device sync event.

Silent push is best-effort and can be throttled. PushKit must not be used for non-VoIP background work.

### Sensitive Routing

Notification policy must decide:

- local only,
- remote allowed,
- in-app only,
- suppressed.

Sensitive topics should not appear in lock-screen preview.

Notification actions should write back durable interaction events:

- answered,
- opened,
- snoozed,
- dismissed,
- marked bad,
- disabled category.

## 6. App-External Capture

v7 should add capture paths that do not require opening the main app first:

- App Intents / Shortcuts / Siri phrases,
- Share Sheet for links/images/screenshots/text,
- quick capture intent for voice/text,
- optional location/time/music reminder intents with explicit opt-in.

These should create a normal `CaptureDraft` and flow through the same context/mood/analyze pipeline.

## 7. Journaling Suggestions

Apple Journaling Suggestions can provide user-selected context:

- location,
- photos/videos,
- music/podcast/media,
- workout/activity,
- contacts/social moments,
- reflection prompts,
- StateOfMind where available.

Mory should treat it as a `ContextEvidenceSource`, not as an automatic background data feed.

Required components:

- entitlement and capability gate,
- OS availability gate,
- `JournalingSuggestionContextService`,
- picker entry point,
- asset parser,
- conversion to `CaptureArtifactDraft`, `ContextEvidence`, and `AffectSnapshot`.

It is not a voice emotion detector and not an automatic background feed from Journal. The user selects what is shared.

## 8. Local ML And System Frameworks

Use local frameworks to reduce cloud dependence:

| Framework | v7 use |
| --- | --- |
| Speech | speech-to-text and optional local transcript hints |
| NaturalLanguage | lightweight language/entity/topic hints |
| Vision / VisionKit | OCR, image labels, document/ticket clues |
| Core ML | optional local affect/tone/classification models |
| AVFoundation | camera/audio capture pipeline |

Local hints are evidence. They should not override user corrections.

## 9. iOS Version Gates

All newer system features must be OS-gated:

- Journaling Suggestions availability,
- StateOfMind support,
- App Intents triggers,
- newer semantic context cues.

Implementation must degrade to:

- manual capture,
- local notifications,
- launch recovery,
- user search/recall.

## 10. Acceptance Criteria

- Daily question preparation no longer depends only on opening Home.
- Deferred analysis can survive app suspension through scheduled jobs or server push.
- Notification source and policy are visible in debug UI.
- App Intents/Share/Journaling Suggestions create normal drafts, not special one-off records.
- Background failures are observable and retried with bounded backoff.

# 06. Background Jobs, Notifications, And Go Server

## 1. Goal

Support useful background preparation without turning the backend into a full memory database.

## 2. iOS Background Work

Use iOS capabilities carefully:

- App foreground refresh.
- Background app refresh when available.
- Local notifications.
- SwiftData pending job queue.
- Retry on next launch.

Do not assume background execution is guaranteed.

## 3. Local Job Recovery

Every job should survive app termination:

```text
pending job stored
  -> app closes
  -> app relaunches
  -> scheduler resumes eligible jobs
```

Jobs that depend on network or cloud AI should fail gracefully and retry later.

Current iOS data-flow status:

- Transcript refinement uses cloud deep intelligence after local/system transcription and falls back to raw transcript if unavailable.
- Daily question preparation now has a gated foreground Home refresh hook: when daily questions and cloud question suggestions are enabled, Mory sends bounded recent-memory evidence to the Go V6 question endpoint and persists returned candidates locally as `ClarificationQuestion`.
- Notification intent preparation now has a local policy path: eligible daily questions can become pending `NotificationIntent` rows only when user preferences, V6 flags, quiet hours, daily limits, and sensitivity rules allow it.
- Local notification scheduling now has a mockable iOS scheduler and `UNUserNotificationCenter` adapter. Foreground Home refresh can schedule pending intents when permission already exists, without prompting.
- Notification opt-in now has a basic settings path: user preferences can request system authorization, enable daily-question notification defaults, update per-type switches, and cancel pending/scheduled local intents when disabled.
- Local notification interactions now support concrete deep-link routes for the first V6 surfaces: daily question opens can push a specific question card, record targets can push memory detail, and chapter/reflection targets can push the corresponding Insights detail screen.
- App launch now runs a lightweight recovery pass: `running` intelligence jobs are reset to `pending`, retryable `failed` jobs are rescheduled with bounded backoff, daily-question preparation is attempted, and pending local notification intents are scheduled when permission already exists.
- This is not yet the final background scheduler. Phase 5 still needs actual execution workers for every recovered job kind, remote push delivery writeback, and polished settings UX.

## 4. Notification Architecture

Local notification path:

```text
Intelligence job creates NotificationIntent
  -> NotificationPolicy checks settings/frequency/sensitivity
  -> LocalNotificationScheduler schedules notification
```

Current implementation boundary:

- `NotificationPolicy` and daily-question intent preparation exist on iOS.
- Pending intents are stored locally and can be tested deterministically.
- `LocalNotificationScheduler` can schedule pending local intents and mark them `scheduled`.
- `NotificationSettingsService` stores user notification preferences separately from rollout flags and system authorization.
- `NotificationInteractionService` resolves local notification metadata, updates delivered/dismissed state, and maps open events to a tab plus optional concrete route.
- `AppIntelligenceRecoveryService` owns launch-time retry/resume bookkeeping and notification preparation recovery.
- Permission prompts are only available from the settings opt-in path, not from passive Home refresh.

Remote notification path:

```text
iOS registers APNs token
  -> Go stores token and preferences
  -> iOS or server creates notification intent
  -> Go sends APNs when remote delivery is appropriate
```

## 5. Go Server Current State

Current server is a light-state service:

- Auth.
- JWT refresh.
- AI gateway.
- User onboarding state.
- Push token registration.
- Subscription mock.

It should remain light-state.

## 6. Go Server Additions

Recommended additions:

```text
internal/notification/
  apns_client.go
  notification_sender.go
  notification_policy.go

internal/intelligence/
  transcript_refine.go
  question_candidates.go
  chapter_candidates.go
```

New endpoints:

```text
POST /api/intelligence/refine-transcript
POST /api/intelligence/suggest-questions
POST /api/intelligence/suggest-chapters
POST /api/notifications/register-preferences
POST /api/notifications/intents
```

## 7. Server Storage Boundary

Server may store:

- `push_tokens`
- `user_profiles`
- `notification_preferences`
- `notification_delivery_log`
- `quota_usage`

Server should not store:

- Full memory records.
- Full artifact text.
- Full graph.
- Full search index.
- Full home board layout.

## 8. Rate Limits And Quotas

Add:

- Per-IP anonymous preview limit.
- Per-user analyze/reflection limit.
- Per-user transcript refinement limit.
- Tier-based quotas.
- Basic abuse logs.

## 9. Logging Privacy

Production logs should avoid raw content:

Allowed:

- request ID.
- user ID hash or user ID if already standard.
- provider.
- model.
- status.
- duration.
- token usage.
- record ID.
- artifact count.

Avoid:

- raw record text.
- full prompt.
- full model response.
- sensitive notification body.

## 10. Naming Cleanup

Server still uses Sprout naming in module paths, prompt text, and OpenAPI title.

V6 should:

- Keep module path stable unless renaming is worth the cost.
- Change prompt-facing product name to Mory.
- Change OpenAPI title to Mory Server API.
- Preserve compatibility for existing endpoints.

## 11. Toolchain Note

Current environment did not have `go` in PATH during exploration. Before server implementation:

```bash
cd server
go test ./...
```

must be restored and run.

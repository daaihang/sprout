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
- This is not yet the final background scheduler. Phase 5 still needs retry policy, notification policy, local notification scheduling, and settings controls.

## 4. Notification Architecture

Local notification path:

```text
Intelligence job creates NotificationIntent
  -> NotificationPolicy checks settings/frequency/sensitivity
  -> LocalNotificationScheduler schedules notification
```

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

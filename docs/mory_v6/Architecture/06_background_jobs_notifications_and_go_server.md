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
- Notification generation now has a single iOS orchestrator path: only daily question, analysis ready, reflection ready, and debug test candidates can become `NotificationIntent` rows. Long-term pattern/revisit signals remain Home/Insights surfaces and do not enter system notifications.
- Local notification scheduling now has a mockable iOS scheduler and `UNUserNotificationCenter` adapter. Foreground Home refresh can schedule pending intents when permission already exists, without prompting.
- Notification opt-in now has a basic settings path: user preferences can request system authorization, enable daily-question notification defaults, update per-type switches, and cancel pending/scheduled local intents when disabled.
- Local notification interactions now support concrete deep-link routes for the first V6 surfaces: daily question opens can push a specific question card, record targets can push memory detail, artifact targets can resolve back to the parent memory detail, and chapter/reflection/entity-family targets can push the corresponding Insights detail screen.
- App launch now runs a lightweight recovery pass: `running` intelligence jobs are reset to `pending`, retryable `failed` jobs are rescheduled with bounded backoff, unified notification-intent preparation is attempted, and pending local notification intents are scheduled when permission already exists.
- The iOS intelligence worker now executes the first expanded recovered job kinds: entity enrichment, clarification question generation, graph delta application, chapter candidate generation, notification intent preparation, semantic indexing, daily question preparation, and local notification scheduling.
- Go now has production APNs token-auth client wiring and a server-side scheduled delivery loop. Remaining Phase 5/6 work is real credential deployment, production observability, and polished settings UX.

## 4. Notification Architecture

Local notification path:

```text
Intelligence job creates NotificationIntent
  -> NotificationPolicy checks settings/frequency/sensitivity
  -> LocalNotificationScheduler schedules notification
```

Current implementation boundary:

- `NotificationPolicy` and a unified local notification-intent preparation service exist on iOS.
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
  -> iOS or server creates notification intent candidate
  -> Go queues a lightweight delivery row
  -> Go APNs worker sends when remote delivery is appropriate
  -> iOS writes delivery/open/dismiss events back
```

Current remote status:

- iOS syncs APNs token, notification preferences, AI toggles, quiet hours, delivery pace, max-per-day, and minimum spacing to `/api/push/register`.
- iOS persists failed delivery writebacks locally and flushes them after the next successful registration sync.
- Go stores push tokens, expanded device preferences, delivery rows, and delivery events.
- Go has an initial `PushDeliveryWorker` that can queue an intent, enforce per-device notification policy, attempt due delivery through an APNs client, and update delivery status.
- Go can now use a real APNs token-auth sender when credentials are configured. Local/dev defaults keep `APNS_ENABLED=false`, which intentionally uses a disabled sender.
- Go runs a configurable scheduled delivery loop via `PUSH_DELIVERY_WORKER_ENABLED`, `PUSH_DELIVERY_INTERVAL`, and `PUSH_DELIVERY_BATCH_SIZE`.
- Go now tracks delivery attempts, transient APNs retries, permanent failures, loop errors, last run/success timestamps, and delivery alert thresholds through `/metrics` and JSON logs.
- Remote push payloads now carry both iOS-compatible flat userInfo keys and a nested production envelope for `record`, `artifact`, `question`, `entity`, `place`, `theme`, `decision`, `chapter`, and `reflection` targets.

## 5. Go Server Current State

Current server is a light-state service:

- Auth.
- JWT refresh.
- AI gateway.
- User onboarding state.
- Push token registration.
- Push delivery queue and interaction writeback.
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
POST /api/intelligence/analyze-photo
POST /api/push/register
POST /api/push/enqueue
POST /api/push/delivery-writeback
```

APNs credential configuration:

```text
APNS_ENABLED=true
APNS_ENVIRONMENT=sandbox|production
APNS_TOPIC=com.speculolabs.mory
APNS_KEY_ID=<Apple key id>
APNS_TEAM_ID=<Apple team id>
APNS_AUTH_KEY_PATH=/path/to/AuthKey_XXXX.p8
# or APNS_AUTH_KEY=<PEM content>
PUSH_DELIVERY_MAX_ATTEMPTS=5
PUSH_DELIVERY_RETRY_BACKOFF=2m
PUSH_DELIVERY_ALERT_FAILURE_THRESHOLD=3
```

Retry and alert policy:

- APNs `429` and `5xx` responses are treated as transient and retried with exponential backoff.
- Missing credentials, disabled APNs, invalid tokens, topic mismatches, and most `4xx` APNs responses are treated as permanent failures.
- The worker stores `attempt_count` and `next_attempt_at` on each delivery row so restarts do not lose retry state.
- `/metrics` exposes `push_delivery_sent_total`, `push_delivery_failed_total`, `push_delivery_retried_total`, `push_delivery_permanent_failed_total`, `push_delivery_loop_errors_total`, `push_delivery_consecutive_loop_errors`, `push_delivery_last_run_unix`, and `push_delivery_last_success_unix`.
- Production deploys should alert on repeated loop errors, spikes in permanent failures, or retries that do not recover into sends.

Remote push production payload shape:

```json
{
  "intent_id": "uuid",
  "kind": "dailyQuestion",
  "title": "Mory",
  "body": "A question is ready.",
  "privacy_level": "contextual",
  "deep_link": "mory://home/question/uuid",
  "target": {
    "type": "question",
    "id": "uuid",
    "parent_record_id": "optional-record-id",
    "artifact_kind": "photo",
    "entity_kind": "decision",
    "label": "display-safe label",
    "source_record_ids": ["uuid"]
  },
  "payload": {
    "schema_version": 1,
    "intent_id": "uuid",
    "kind": "dailyQuestion",
    "delivery_channel": "remote",
    "target": {
      "type": "question",
      "id": "uuid"
    }
  },
  "scheduled_at": "2026-05-19T12:00:00Z"
}
```

The APNs body includes flat keys for the existing iOS notification parser:

```text
mory_notification_intent_id
mory_notification_kind
mory_notification_target_type
mory_notification_target_id
```

and a nested `mory` object with the full envelope above.

## 6.1 Cloud Deep Intelligence Provider Loop

Current server AI status:

- `AI_MODE=mock` remains the deterministic default for local/dev.
- `AI_MODE=live` supports `AI_PROVIDER=openai_compatible` and `AI_PROVIDER=anthropic`.
- V6 endpoints now use provider-backed operations for transcript refinement, question suggestions, chapter/stage suggestions, and photo semantic analysis. Notification intent generation is local-only through the iOS orchestrator.
- Each V6 operation now has an explicit JSON shape embedded in the system prompt, and all responses are parsed, normalized, metered, and returned with provider/model/token metadata.
- `/metrics` exposes `ai_operation_requests_total`, `ai_operation_errors_total`, `ai_operation_average_latency_ms`, `ai_operation_input_tokens_total`, and `ai_operation_output_tokens_total` by operation/provider.

Deployment guidance:

- Use `openai_compatible` for OpenAI-compatible APIs such as DeepSeek or OpenAI Chat Completions.
- Keep `AI_MAX_RETRIES` and `AI_RETRY_BACKOFF` conservative until live latency is measured.
- Treat model outputs as candidates; iOS remains the source of truth and should confirm or store only accepted durable changes.

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

Current environment does not have `go` in PATH, but GoLand installed Go at:

```text
/Users/z14/sdk/go1.26.3/bin/go
```

Before server implementation:

```bash
cd server
/Users/z14/sdk/go1.26.3/bin/go test ./...
```

must be run.

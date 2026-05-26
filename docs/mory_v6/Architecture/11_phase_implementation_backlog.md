# 11. Phase Implementation Backlog

## 1. Goal

Turn V6 documents into implementation-ready phases.

This backlog is deliberately more concrete than the release summary. Each phase should be shippable, testable, and reversible.

## 2. Phase 0: Documentation, Flags, And Baseline

Outcome:

```text
V6 can be developed behind flags without affecting current v5 behavior.
```

Tasks:

- Add V6 feature flag model.
- Add intelligence preferences domain model.
- Add settings placeholders hidden behind debug flag.
- Add test fixtures for sample memories/entities.
- Add architecture docs to project planning.

Files:

```text
Domain/Intelligence/IntelligencePreferences.swift
App/MoryAppDependencies.swift
Features/Settings/SettingsSupport.swift
```

Tests:

- Preference defaults.
- Feature flag defaults.
- No V6 cards appear when flags are off.

Exit criteria:

- App builds.
- Existing tests pass.
- V6 has no visible impact unless enabled.

## 3. Phase 1: Domain And Persistence

Outcome:

```text
Mory can store V6 intelligence objects locally.
```

Tasks:

- Add `EntityProfile`.
- Add `ClarificationQuestion`.
- Add `IntelligenceJob`.
- Add `GraphDelta`.
- Add SwiftData stores.
- Add mappers.
- Add repository protocol methods.
- Add `clearAllLocalData` cleanup.

Files:

```text
Domain/Intelligence/
Persistence/Models/MoryStoreModels.swift
Persistence/Mappers/MoryDomainMappers.swift
Persistence/Repositories/MoryMemoryRepository.swift
Persistence/Stack/MoryPersistenceStack.swift
```

Tests:

- Store round trip.
- Mapper round trip.
- Schema opens existing data.
- Clear local data removes V6 stores.

Exit criteria:

- No destructive migration.
- V6 objects can be created, updated, dismissed, answered.

## 4. Phase 2: First Intelligence Loop

Outcome:

```text
Mory asks a useful person clarification question after capture analysis.
```

Tasks:

- Hook post-analysis scheduler in repository.
- Build local person profile updater.
- Build question generator for missing relationship/alias.
- Build graph delta applier for answer.
- Add Home question card.
- Add entity detail question row if target exists.

Files:

```text
Infrastructure/Intelligence/IntelligenceScheduler.swift
Infrastructure/Intelligence/EntityEnrichmentService.swift
Infrastructure/Intelligence/ClarificationQuestionBuilder.swift
Infrastructure/Intelligence/GraphDeltaApplier.swift
Features/Intelligence/ClarificationQuestionCard.swift
Features/Home/HomeScreen.swift
Domain/Composition/HomeBoardRuleEngine.swift
```

Tests:

- New person creates question.
- Known person does not spam question.
- Dismiss persists.
- Answer creates graph/profile update.
- Home card disappears after answer.

Exit criteria:

- User-visible AI-native loop works with local deterministic fallback, while cloud deep-intelligence contracts can later improve candidate quality.

## 5. Phase 3: Home Memory Desktop

Outcome:

```text
Home becomes a user-controlled grid with assistant suggestion layer.
```

Tasks:

- Add grid span model.
- Add card layout model.
- Add `LazyVGrid` or custom `Layout`.
- Add fixed card sizes.
- Add edit mode.
- Add pin/hide/dismiss/resize.
- Add yesterday panel and today suggestions.
- Preserve current list fallback during rollout.

Files:

```text
Features/Home/Grid/HomeBoardGridLayout.swift
Features/Home/Grid/HomeBoardSpan.swift
Features/Home/Grid/HomeBoardGridMetrics.swift
Features/Home/Cards/
Domain/Composition/Composition.swift
Domain/Composition/HomeBoardRuleEngine.swift
```

Tests:

- 4-column compact layout.
- 8-column regular layout.
- Pinned cards keep order.
- Suggestions cannot replace pinned cards.
- Dismissed suggestion stays dismissed.

Exit criteria:

- Home feels spatial, not like a moving feed.

## 6. Phase 4: Semantic Search

Outcome:

```text
Search can find memories by meaning while preserving exact search fallback.
```

Tasks:

- Add Spotlight index service.
- Index records and selected artifact text.
- Add Core Spotlight semantic query path where available.
- Merge exact, graph, and semantic results.
- Add result explanation.
- Add reindex debug action.

Files:

```text
Infrastructure/Search/SpotlightIndexService.swift
Infrastructure/Search/SpotlightSearchService.swift
Infrastructure/Search/SearchResultMerger.swift
Features/Search/SearchScreen.swift
```

Tests:

- Index create/update/delete.
- Search fallback when semantic unavailable.
- Result merge de-duplicates.
- Private records are not indexed if user disables search indexing.

Exit criteria:

- Search tab remains familiar but becomes meaning-aware on supported systems.

## 7. Phase 5: Daily Questions And Notifications

Outcome:

```text
Mory can ask timely questions with frequency and privacy controls.
```

Tasks:

- Add daily question engine.
  - Current implementation status: iOS now has a cloud-backed `DailyQuestionSuggestionService` that can turn recent-memory evidence into persisted `ClarificationQuestion` rows when user preferences and V6 flags allow it. It is wired into Home refresh as a data-flow hook, with visual polish deferred.
- Add notification intent store.
  - Current implementation status: iOS has `NotificationIntent` persistence, repository fetch/upsert APIs, and mapper round-trip support.
- Add notification policy.
  - Current implementation status: iOS has `NotificationPolicy` checks for master switch, local-notification flag, notification type switch, max-per-day, quiet hours, sensitive-topic suppression, and rich-preview downgrade to generic copy.
- Add notification intent preparation.
  - Current implementation status: superseded by the unified `NotificationOrchestrator`. System notifications are now limited to daily question, analysis ready, reflection ready, and debug test; long-term pattern signals stay inside Home/Insights and do not become push intents.
- Add local scheduler.
  - Current implementation status: iOS has a mockable `LocalNotificationScheduler` plus `UNUserNotificationCenter` adapter. The Home foreground refresh path attempts to schedule pending intents only when notification permission is already available; it does not prompt yet.
- Add settings UI.
  - Current implementation status: iOS has a basic native Settings route for notification preferences, including master enablement, per-type switches, max-per-day, rich-preview preference, system authorization state, and rollout flag visibility.
- Add permission flow.
  - Current implementation status: notification permission is requested only through the explicit settings opt-in path. Passive Home refresh still avoids permission prompts.
- Add quiet hours and max-per-day.
  - Current implementation status: max-per-day, delivery pace, minimum spacing, and minute-precise quiet hours are editable in the basic settings route and enforced by `NotificationPolicy`.
- Add notification interaction handling.
  - Current implementation status: local notification payload metadata is centralized; app-level `UNUserNotificationCenterDelegate` handling records foreground delivery, open, and dismiss events; open events can deep-link to a specific daily question card, memory detail, artifact-parent memory detail, chapter candidate, reflection detail, or supported Insights entity target when the payload target supports it.
- Add retry/resume on app launch.
  - Current implementation status: `BackgroundOperationOrchestrator` records the app-launch run and delegates job retry/resume bookkeeping to `IntelligenceJobRecoveryService`, which resets interrupted running jobs to pending and reschedules retryable failed jobs with bounded backoff. Notification preparation is routed through the notification domain without passive permission prompts.
- Add push delivery writeback and APNs preference sync.
  - Current implementation status: iOS now syncs APNs token, notification preferences, AI/search/home toggles, quiet hours, delivery pace, max-per-day, and minimum spacing to Go `/api/push/register`.
  - Current implementation status: iOS writes delivered/opened/dismissed interactions to `/api/push/delivery-writeback`, stores failed writebacks locally, and flushes them after the next successful push registration sync.
- Add notification/debug observability.
  - Current implementation status: the internal Debug Center exposes Remote Push diagnostics and Job Queue diagnostics, including local intent counts, due jobs, worker execution, launch recovery, graph delta state, and copyable reports for debugging notification preparation and delivery.

Files:

```text
Infrastructure/Intelligence/DailyQuestionEngine.swift
Infrastructure/Intelligence/Jobs/IntelligenceJobRecoveryService.swift
Infrastructure/Background/BackgroundOperationOrchestrator.swift
Infrastructure/Notifications/LocalNotificationScheduler.swift
Infrastructure/Notifications/NotificationPolicy.swift
Features/Settings/
Features/Intelligence/DailyQuestionCard.swift
```

Tests:

- Quiet hours block scheduling.
- Max-per-day enforced.
- Sensitive topic blocked by policy.
- Notification opt-in persists preferences and requests system authorization.
- Disabling notifications cancels pending/scheduled local intents.
- Notification open resolves a route and delivery/dismissal updates persist.
- App relaunch recovers interrupted jobs and notification preparation.
- Minute-precise quiet hours and minimum notification spacing are enforced.
- Remote writeback retry survives transient server failure.

Exit criteria:

- Notifications are useful but never uncontrolled.

## 8. Phase 6: Go Server V6 Contracts

Outcome:

```text
Server supports cloud deep-intelligence contracts without storing the memory library.
```

Tasks:

- Add transcript refinement endpoint.
- Add question candidate endpoint.
- Add chapter candidate endpoint.
- Add photo semantic analysis placeholder endpoint.
- Keep notification intent generation local to the iOS orchestrator; server only delivers queued push payloads.
- Add notification preference endpoint.
- Add rate limit middleware.
- Update OpenAPI.
- Add privacy-safe logging.
- Add tests.

Current implementation status:

- Go V6 endpoints and OpenAPI contracts exist for transcript refinement, question suggestions, chapter suggestions, and photo semantic placeholders. Notification intent suggestion was removed from the server contract; iOS owns notification candidate generation through `NotificationOrchestrator`.
- Go push endpoints now include `/api/push/register` preference payload expansion, `/api/push/enqueue` lightweight delivery queuing/due-delivery attempt, and `/api/push/delivery-writeback` interaction writeback.
- Go has an initial `internal/notification/PushDeliveryWorker` that enforces stored device preferences, quiet hours, daily caps, and minimum spacing before sending through an APNs client.
- Go now has a real token-auth APNs client behind `APNS_ENABLED=true`, plus credential config for key ID, team ID, topic, environment, and `.p8` auth key path/content.
- Go now has a long-running scheduled delivery loop controlled by `PUSH_DELIVERY_WORKER_ENABLED`, `PUSH_DELIVERY_INTERVAL`, and `PUSH_DELIVERY_BATCH_SIZE`.
- Go push delivery now persists `attempt_count` and `next_attempt_at`, retries transient APNs failures with exponential backoff, permanently fails non-retryable APNs errors, and exposes delivery counters/timestamps through `/metrics`.
- Remote push enqueue payloads now include a production target envelope for `record`, `artifact`, `question`, `entity`, `place`, `theme`, `decision`, `chapter`, and `reflection`, while preserving flat iOS userInfo keys in the APNs payload.
- iOS clients/protocols exist for those endpoints.
- iOS debug settings now expose APNs token presence, device/timezone state, registration digest state, pending writeback count, notification-intent counts, force sync, and a basic enqueue-first-pending-intent action.
- iOS Debug Center now includes Cloud Intelligence Debug for all V6 cloud operations, with decoded outputs, provider/model metadata, token usage when returned, request IDs, and transport error traces.
- iOS Debug Center now includes Semantic Search Debug and Home Board Debug so search indexing/retrieval and memory desktop card generation can be inspected without direct database access.
- Cloud V6 intelligence is now provider-backed in live mode with explicit per-operation JSON shape prompts and operation-level `/metrics` counters for requests, errors, latency, and token usage.
- Cloud V6 responses now include `meta.prompt_version`, and the Go service exports `cloud_intelligence_prompt_version_info` in `/metrics` for rollout traceability.
- Go now exposes `POST /api/intelligence/eval` for provider smoke-eval of transcript refinement and daily-question suggestion contracts.
- Go AI handlers now apply per-user/per-operation minute rate limiting (`AI_RATE_LIMIT_PER_MINUTE`) and return classified error payloads with retryability hints.
- `/metrics` now emits per-operation AI error classes (`ai_operation_errors_by_class_total`) for provider hardening and alerting.
- iOS Remote Push Debug now loads and renders server worker metrics (`apns_environment_info`, worker enabled state, sent/failed/retried/permanent-failed counters, last error).
- Semantic-first search now carries explainable hit reasons per memory (record/artifact/entity/context/spotlight), and Search UI/Debug surfaces these reasons directly.
- Transcript refinement is wired into the unified capture composer.
- Daily question suggestion is wired into the iOS Home data flow as a gated business path that persists local questions.
- The iOS launch/recovery worker now executes expanded due job kinds: entity enrichment, clarification question generation, graph delta application, chapter candidate generation, notification intent preparation, semantic indexing, daily question preparation, and local notification scheduling.
- Local validation covers iOS clients/services and Go server tests. The GoLand-installed toolchain is `/Users/z14/sdk/go1.26.3/bin/go`.

Files:

```text
server/internal/ai/types.go
server/internal/ai/prompt.go
server/internal/http/server.go
server/internal/http/handlers.go
server/internal/intelligence/
server/internal/notification/
server/internal/ratelimit/
server/openapi.yaml
mory/mory/Infrastructure/Networking/
mory/mory/Infrastructure/Intelligence/
```

Tests:

- `go test ./...`
- Endpoint schema validation.
- Provider failure mapping.
- Rate limit behavior.
- Mock provider returns stable transcript/question/chapter/photo/notification candidates.

Exit criteria:

- Cloud calls are bounded, auditable, and do not turn the server into a private memory store.

## 9. Phase 7: Multimedia Views

Outcome:

```text
Mory can be reviewed through emotional/native memory surfaces, not only lists.
```

Tasks:

- Film gallery.
- Storage jar.
- Sticker wall.
- Chapter list/detail.
- Yesterday review panel.
- Multimedia article preview.

Files:

```text
Features/MemoryViews/FilmGalleryView.swift
Features/MemoryViews/StorageJarView.swift
Features/MemoryViews/StickerWallView.swift
Features/Chapters/
```

Tests:

- All views use same memory source.
- Filters carry across compatible views.
- Empty states are clear.
- Performance with sample library.

Exit criteria:

- V6 memory review feels richer than a form/list app.

## 10. Phase 8: Privacy, Quality, And RC

Outcome:

```text
V6 is safe enough for beta users.
```

Tasks:

- Privacy copy review.
- Migration review.
- Real-device smoke.
- Local quality batch.
- Accessibility pass.
- Notification copy review.
- Performance profiling.
- Crash/error telemetry check.

Tests:

- Full iOS test suite.
- Local sample data quality batch.
- Real-device capture/search/notification smoke.
- Server tests.

Exit criteria:

- No destructive migration.
- No uncontrolled notification behavior.
- No cloud AI call without setting/consent.
- Existing V5 workflows still work.

## 11. PR Slicing Rule

Each PR should produce one of:

- New domain capability with tests.
- New persistence capability with migration test.
- New visible UI loop behind flag.
- New server endpoint with OpenAPI/test.
- New debug or quality tool.

Avoid PRs that mix:

- Large UI redesign.
- Schema migration.
- Server contract change.
- Notification behavior.

unless the feature cannot be tested otherwise.

## 12. First Three PRs

Recommended sequence:

1. `v6-intelligence-models`
   - Domain models, stores, mappers, tests.

2. `v6-person-question-loop`
   - Scheduler, question builder, graph delta applier, home card.

3. `v6-home-grid-foundation`
   - Grid model, layout metrics, feature-flagged home implementation.

These give the project a working spine before adding Core ML, Core Spotlight, notifications, and server V6 contracts.

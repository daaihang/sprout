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
  - Current implementation status: iOS has `NotificationIntentPreparationService` that turns eligible pending daily questions into local pending notification intents without scheduling system notifications yet.
- Add local scheduler.
- Add settings UI.
- Add permission flow.
- Add quiet hours and max-per-day.

Files:

```text
Infrastructure/Intelligence/DailyQuestionEngine.swift
Infrastructure/Notifications/LocalNotificationScheduler.swift
Infrastructure/Notifications/NotificationPolicy.swift
Features/Settings/
Features/Intelligence/DailyQuestionCard.swift
```

Tests:

- Quiet hours block scheduling.
- Max-per-day enforced.
- Sensitive topic blocked by policy.
- Notification tap resolves deep link.

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
- Add notification intent suggestion endpoint.
- Add notification preference endpoint.
- Add rate limit middleware.
- Update OpenAPI.
- Add privacy-safe logging.
- Add tests.

Current implementation status:

- Go V6 endpoints and OpenAPI contracts exist for transcript refinement, question suggestions, chapter suggestions, photo semantic placeholders, and notification intent suggestions.
- iOS clients/protocols exist for those endpoints.
- Transcript refinement is wired into the unified capture composer.
- Daily question suggestion is wired into the iOS Home data flow as a gated business path that persists local questions.
- Local validation covers iOS clients/services; Go validation still requires a local Go toolchain.

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

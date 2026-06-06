# 08. Project File Plan

## 1. Goal

Define exactly where v6 implementation should land.

## 2. New iOS Directories

```text
mory/mory/Domain/Intelligence/
mory/mory/Infrastructure/Intelligence/
mory/mory/Infrastructure/Search/
mory/mory/Infrastructure/Notifications/
mory/mory/Features/Intelligence/
mory/mory/Features/Home/Layout/
mory/mory/Features/Home/Cards/
```

## 3. New Domain Files

```text
Domain/Intelligence/EntityProfile.swift
Domain/Intelligence/ClarificationQuestion.swift
Domain/Intelligence/IntelligenceJob.swift
Domain/Intelligence/GraphDelta.swift
Domain/Intelligence/HomeBoardSignal.swift
Domain/Intelligence/NotificationIntent.swift
Domain/Intelligence/IntelligencePreferences.swift
```

## 4. New Infrastructure Files

```text
Infrastructure/Intelligence/IntelligenceScheduler.swift
Infrastructure/Intelligence/EntityEnrichmentService.swift
Infrastructure/Intelligence/ClarificationQuestionBuilder.swift
Infrastructure/Intelligence/GraphDeltaApplier.swift
Infrastructure/Intelligence/LocalSignalExtractor.swift
Infrastructure/Intelligence/DailyQuestionEngine.swift

Infrastructure/Search/SpotlightIndexService.swift
Infrastructure/Search/SpotlightSearchService.swift
Infrastructure/Search/SearchResultMerger.swift

Infrastructure/Notifications/LocalNotificationScheduler.swift
Infrastructure/Notifications/NotificationPolicy.swift
```

## 5. New Feature Files

```text
Features/Intelligence/ClarificationQuestionCard.swift
Features/Intelligence/EntityConfirmationView.swift
Features/Intelligence/DailyQuestionCard.swift

Features/Home/Layout/HomeBoardMasonryLayout.swift
Features/Home/Layout/HomeBoardItemLayout.swift
Domain/BoardLayout/MoryMasonryLayout.swift

Features/Home/Cards/HomeMemoryCard.swift
Features/Home/Cards/HomeQuestionCard.swift
Features/Home/Cards/HomeSystemCard.swift
Features/Home/Cards/HomeSuggestionCard.swift
Features/Home/Cards/HomeChapterCandidateCard.swift
```

## 6. Existing iOS Files To Modify

### Persistence

```text
Persistence/Models/MoryStoreModels.swift
Persistence/Mappers/MoryDomainMappers.swift
Persistence/Stack/MoryPersistenceStack.swift
Persistence/Repositories/MoryMemoryRepository.swift
```

Changes:

- Add stores.
- Add schema entries.
- Add mappers.
- Add repository fetch/upsert/answer/dismiss methods.
- Add cleanup in `clearAllLocalData`.

### Domain

```text
Domain/Memory/MemoryFeatureModels.swift
Domain/Composition/Composition.swift
Domain/Composition/HomeBoardRuleEngine.swift
```

Changes:

- Add repository protocol methods.
- Add new card kinds when ready.
- Feed HomeBoardSignals and questions into board candidates.

### Features

```text
Features/Home/HomeScreen.swift
Features/Search/SearchScreen.swift
Features/Settings/SettingsScreen.swift
Features/Settings/SettingsSupport.swift
Features/MemoryDetail/MemoryDetailView.swift
Features/Entities/EntityDetailView.swift
Features/People/PersonDetailView.swift
```

Changes:

- Home masonry and suggestion layer.
- Semantic search path.
- AI/privacy/notification settings.
- Show unresolved questions on relevant details.

### App

```text
App/MoryApp.swift
App/MoryAppDependencies.swift
App/MoryRootView.swift
```

Changes:

- Add environment dependency if repository splits.
- Request notification permissions when user opts in.
- Trigger foreground scheduler if appropriate.

## 7. Go Server Files To Modify

```text
server/internal/ai/types.go
server/internal/ai/prompt.go
server/internal/http/server.go
server/internal/http/handlers.go
server/internal/db/sqlite.go
server/internal/config/config.go
server/openapi.yaml
```

New directories:

```text
server/internal/intelligence/
server/internal/push/
server/internal/ratelimit/
```

Changes:

- Add transcript refinement endpoint.
- Add question/chapter candidate endpoint.
- Add rate limits and quotas.
- Add notification preference/intent storage.
- Add APNs sender when remote push is approved.
- Update OpenAPI and tests.

## 8. Test Files

Add:

```text
mory/moryTests/IntelligenceDomainTests.swift
mory/moryTests/ClarificationQuestionBuilderTests.swift
mory/moryTests/MoryMemoryRepositoryIntelligenceTests.swift
mory/moryTests/MoryMasonryLayoutTests.swift
mory/moryTests/SpotlightIndexServiceTests.swift

server/internal/intelligence/intelligence_test.go
server/internal/push/push_delivery_worker_test.go
server/internal/http/intelligence_handlers_test.go
```

## 9. First Pull Request Slice

Recommended first implementation PR:

```text
Add person clarification loop
```

Files:

- `Domain/Intelligence/EntityProfile.swift`
- `Domain/Intelligence/ClarificationQuestion.swift`
- `Domain/Intelligence/IntelligenceJob.swift`
- SwiftData stores and mappers.
- Repository methods.
- `ClarificationQuestionBuilder`.
- Home question card.
- Tests.

User-visible result:

```text
Mory detects a person.
Mory asks who they are.
User answers.
Mory remembers the relationship.
```

This proves v6 without touching every future system at once.

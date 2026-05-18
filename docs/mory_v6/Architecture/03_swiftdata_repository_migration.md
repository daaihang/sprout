# 03. SwiftData, Repository, And Migration

## 1. Goal

Add v6 persistence safely.

Current SwiftData schema is centralized in:

```text
mory/mory/Persistence/Models/MoryStoreModels.swift
mory/mory/Persistence/Stack/MoryPersistenceStack.swift
mory/mory/Persistence/Mappers/MoryDomainMappers.swift
```

V6 should append new stores and mappers without destructive changes.

## 2. New Stores

Add:

```text
EntityProfileStore
ClarificationQuestionStore
IntelligenceJobStore
GraphDeltaStore
HomeBoardSignalStore
NotificationIntentStore
IntelligencePreferenceStore
SemanticIndexMetadataStore
```

Initial alpha can start with:

```text
EntityProfileStore
ClarificationQuestionStore
IntelligenceJobStore
```

## 3. Schema Strategy

Current model configuration name:

```swift
ModelConfiguration("MoryV1", schema: schema, ...)
```

Adding new model types is usually lightweight, but must be tested against existing local stores.

Rules:

- Do not rename existing stores.
- Do not change existing unique attributes.
- Do not change existing field types.
- Prefer optional fields with defaults for new concepts.
- Add stores before changing existing model contracts.

## 4. Mappers

For each store:

```swift
extension EntityProfileStore {
    convenience init(domainModel: EntityProfile)
    var domainModel: EntityProfile
    func apply(domainModel: EntityProfile)
}
```

Mapper rules:

- Raw enum values must fallback to safe defaults.
- Codable payloads must be optional and resilient.
- Unknown future values should not crash the app.

## 5. Repository Shape

Current `MoryMemoryRepositorying` is already broad. Two options:

### Option A: Extend Existing Protocol

Fastest for alpha:

```swift
func fetchClarificationQuestions(status: ClarificationQuestionStatus?, limit: Int?) throws -> [ClarificationQuestion]
func answerClarificationQuestion(_ id: UUID, answer: ClarificationAnswer) throws
func dismissClarificationQuestion(_ id: UUID) throws
func fetchEntityProfile(entityID: UUID) throws -> EntityProfile?
func upsertEntityProfile(_ profile: EntityProfile) throws
func fetchIntelligenceJobs(status: IntelligenceJobStatus?, limit: Int?) throws -> [IntelligenceJob]
```

Pros:

- Minimal dependency injection work.
- Easy to expose to existing screens.

Cons:

- Protocol grows larger.

### Option B: Add `MoryIntelligenceRepositorying`

Cleaner long term:

```swift
protocol MoryIntelligenceRepositorying: AnyObject { ... }
```

Pros:

- Better domain separation.

Cons:

- Requires new environment key and app wiring.

Recommendation:

- Use Option A for alpha.
- Split into Option B after first loop stabilizes.

## 6. Integration Points

Modify:

```text
MoryMemoryRepository.refreshMemoryPipeline(recordID:)
```

After successful pipeline completion:

```swift
try intelligenceScheduler.enqueuePostAnalysisJobs(recordID: recordID)
```

For alpha, scheduler can be a repository-private service initialized in `MoryMemoryRepository`.

## 7. Delete And Refresh Behavior

When deleting a memory:

- Remove questions sourced only by that record.
- Remove graph deltas sourced only by that record.
- Update entity profiles by removing source record IDs.
- Keep user-confirmed relationship if it has other evidence.
- Delete semantic index item.

When refreshing analysis:

- Mark old analysis-derived questions as stale.
- Keep user-confirmed answers.
- Recompute questions from new analysis.

## 8. Clear Local Data

Update:

```text
MoryMemoryRepository.clearAllLocalData()
```

Delete new stores before core memory stores:

```text
NotificationIntentStore
HomeBoardSignalStore
GraphDeltaStore
IntelligenceJobStore
ClarificationQuestionStore
EntityProfileStore
SemanticIndexMetadataStore
```

## 9. Tests

Required:

- Store mapper roundtrip tests.
- Repository upsert/fetch tests.
- Delete memory removes stale questions.
- Refresh analysis does not delete user-confirmed profile facts.
- Existing v5 repository composition tests still pass.
- In-memory SwiftData model container opens with new schema.


# Mory v6 Architecture Index

## 1. Purpose

This architecture set defines how to implement v6 Continuous Memory Intelligence without destabilizing the v5 stack.

The guiding architecture decision:

> Add a continuous intelligence layer beside the existing memory pipeline. Do not rewrite Record, Artifact, Graph, Arc, Reflection, or Capture before the new loop proves itself.

## 2. Current Code Baseline

Relevant existing files:

- App shell: `/Users/z14/Documents/sprout/mory/mory/App/MoryRootView.swift`
- Repository protocol: `/Users/z14/Documents/sprout/mory/mory/Domain/Memory/MemoryFeatureModels.swift`
- Repository implementation: `/Users/z14/Documents/sprout/mory/mory/Persistence/Repositories/MoryMemoryRepository.swift`
- SwiftData stores: `/Users/z14/Documents/sprout/mory/mory/Persistence/Models/MoryStoreModels.swift`
- SwiftData schema: `/Users/z14/Documents/sprout/mory/mory/Persistence/Stack/MoryPersistenceStack.swift`
- Analysis pipeline: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/AnalysisExecutor.swift`
- Home board rules: `/Users/z14/Documents/sprout/mory/mory/Domain/Composition/HomeBoardRuleEngine.swift`
- Search service: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Graph/MemorySearchService.swift`
- Go API routes: `/Users/z14/Documents/sprout/server/internal/http/server.go`
- Go AI schema: `/Users/z14/Documents/sprout/server/internal/ai/types.go`

## 3. Architecture Documents

| Document | Role |
| --- | --- |
| [01 Continuous Intelligence Layer](01_continuous_intelligence_layer.md) | Defines the new orchestration layer and job lifecycle. |
| [02 Domain Model Extensions](02_domain_model_extensions.md) | Defines new domain objects: jobs, questions, profiles, graph deltas, notification intents. |
| [03 SwiftData Repository Migration](03_swiftdata_repository_migration.md) | Defines persistence, schema, mapper, and repository changes. |
| [04 SwiftUI Home Grid And UI System](04_swiftui_home_grid_and_ui_system.md) | Defines native SwiftUI grid, board layers, and card component architecture. |
| [05 Core ML And Core Spotlight](05_core_ml_and_core_spotlight.md) | Defines lightweight native/system intelligence and semantic search integration. |
| [06 Background Jobs Notifications And Go Server](06_background_jobs_notifications_and_go_server.md) | Defines background execution, notifications, and backend changes. |
| [07 Testing Observability Rollout](07_testing_observability_rollout.md) | Defines tests, debug surfaces, metrics, and rollout phases. |
| [08 Project File Plan](08_project_file_plan.md) | Defines exact file/directory additions and modification points. |
| [09 Go Server API Contracts](09_go_server_api_contracts.md) | Defines V6 backend endpoints, schemas, privacy boundaries, and rate-limit requirements. |
| [10 Settings Preferences And Feature Flags](10_settings_preferences_and_feature_flags.md) | Defines user controls, rollout flags, defaults, and settings UI structure. |
| [11 Phase Implementation Backlog](11_phase_implementation_backlog.md) | Defines implementation-ready phases, files, tests, and exit criteria. |

## 4. High-Level Architecture

```text
Capture
  -> RecordShell + Artifacts
  -> Existing Analysis Pipeline
  -> Graph / Arc / Reflection
  -> V6 Continuous Intelligence Scheduler
      -> IntelligenceJob
      -> EntityProfile
      -> ClarificationQuestion
      -> GraphDelta
      -> SemanticIndex
      -> HomeBoardSignals
      -> NotificationIntent
```

## 5. Responsibility Boundaries

| Layer | Owns | Must Not Own |
| --- | --- | --- |
| Domain | Stable models, policies, snapshots | SwiftUI views, network calls |
| Infrastructure | External systems, indexing, AI calls, background execution | Product UI |
| Persistence | SwiftData stores and mappers | Product decisions |
| Features | SwiftUI screens and components | AI prompt logic |
| Go server | Auth, AI provider keys, deep AI contracts, APNs, light state | Full private memory library |

## 6. First Implementation Slice

Start with the smallest complete v6 loop:

```text
Person entity detected
  -> post-analysis job created
  -> entity profile created or updated
  -> clarification question generated
  -> home shows question card
  -> user answers relationship/alias
  -> graph/profile updated
  -> search/home/person detail reflect answer
```

This gives users a concrete AI-native feeling without requiring the entire v6 system to ship at once.

## 7. Do Not Start By Rewriting

Avoid these first moves:

- Replacing the whole home stack before intelligence objects exist.
- Adding server AI endpoints before local question/profile storage exists.
- Building Core ML integration before fallback signal extraction works.
- Shipping notifications before frequency and sensitivity policy exists.
- Replacing artifact storage before the whole-record UX and article path are defined.

The architecture should grow from a small closed loop, not a wide speculative rewrite.

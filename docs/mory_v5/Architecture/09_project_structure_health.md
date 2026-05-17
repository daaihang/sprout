# 09. Project Structure Health

## 1. Goal

v5 is a presentation-heavy release, so the codebase needs clear ownership boundaries before UI work accelerates.

This document records the current healthy baseline and the guardrails for future splits. It is intentionally about file placement and maintainability, not runtime behavior.

## 2. Current Baseline

The app keeps the main product layers:

```text
mory/mory/
  App/
  Debug/
  Domain/
  Features/
  Infrastructure/
  Persistence/
```

The current structure is acceptable for v5 because responsibilities are mostly separated:

- `App` owns application bootstrap and dependency injection.
- `Domain` owns product concepts, rules, and repository protocols.
- `Features` owns SwiftUI product surfaces and reusable feature components.
- `Infrastructure` owns external services, AI pipeline implementation, capture services, context services, networking, and auth implementation.
- `Persistence` owns SwiftData models, mappers, repositories, and stack creation.
- `Debug` owns internal diagnostics and quality tools only.

## 3. Confirmed Structural Moves

The following organization is the v5 baseline:

```text
Domain/
  Memory/

Infrastructure/
  Analysis/
    Artifacts/
    Graph/
    Pipeline/
    Quality/
    Temporal/

Persistence/
  Mappers/
  Models/
  Repositories/
  Stack/
```

These moves are file-organization changes only. They must not alter AI behavior, repository behavior, routing, storage schema, or UI output.

## 4. Placement Rules

Use these rules when adding or moving files:

| Code Type | Location |
|-----------|----------|
| SwiftUI screen | `Features/<Surface>/` |
| Reusable feature component | `Features/<Surface>/Components/` or `Features/Shared/` |
| Product rule or ranking engine | `Domain/<Area>/` |
| External service adapter | `Infrastructure/<Area>/` |
| AI request, parse, gate, graph, arc, or quality implementation | `Infrastructure/Analysis/<Subarea>/` |
| SwiftData model | `Persistence/Models/` |
| Domain-store mapping | `Persistence/Mappers/` |
| Repository implementation | `Persistence/Repositories/` |
| ModelContainer and storage bootstrap | `Persistence/Stack/` |
| Internal-only diagnostic UI | `Debug/` |

Do not place product UI in `Debug`, storage objects in `Features`, or AI prompt/gate logic inside SwiftUI views.

## 5. File Size Guardrails

These are soft limits. Exceeding them is allowed briefly, but the next refactor should split the file before adding new responsibility.

| File Kind | Target |
|-----------|--------|
| Product SwiftUI screen | 250-400 lines |
| Feature component | 80-220 lines |
| Domain rule engine | 200-400 lines |
| Repository implementation file | 300-500 lines |
| SwiftData model file | 200-400 lines |
| Mapper file | 200-400 lines |
| Debug page file | 300-600 lines |
| Test file | 300-700 lines |

If a file grows because it owns multiple subfeatures, split by responsibility before changing behavior.

## 6. Known Large Files

These files are allowed to exist for the current baseline, but should be split before or during v5 UI work:

| File | Risk | Preferred Split |
|------|------|-----------------|
| `DebugDiagnosticsView.swift` | Debug pages are packed into one large view | Split by debug page or tool area |
| `MoryMemoryRepository.swift` | Mutations, queries, graph persistence, pipeline persistence, and debug support share one file | Split into repository extensions or helper services |
| `MoryStoreModels.swift` | Multiple store model families share one file | Split by capture, graph, reflection, preference, pipeline |
| `MoryDomainMappers.swift` | Mapping logic is broad and hard to scan | Split by the same model families as store models |
| `MoryMemoryRepositoryCompositionTests.swift` | Test scenarios are too broad for one file | Split by capture, board, graph, reflection, cleanup, quality |

`CaptureComposerView.swift` and `HomeScreen.swift` are also sizeable, but they should be split as part of the v5 UI/UX redesign to avoid churn.

## 7. Commit Policy

Structure-only commits should:

- Use `git add -A` so file moves are recorded as renames.
- Avoid behavioral changes.
- Avoid Xcode project churn unless required.
- Exclude `.idea/`, `server/.env`, `.DS_Store`, build products, and local simulator artifacts.
- Pass `xcodebuild build`.
- Prefer `build-for-testing` when full simulator test execution is blocked by CoreSimulator state.

## 8. Acceptance Criteria

A structure change is acceptable when:

- The app builds.
- The test bundle builds.
- Old file paths are not referenced by source code.
- No tracked local-only files are introduced.
- Public product behavior is unchanged.
- The new location makes ownership clearer than the old one.

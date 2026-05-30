# Sprout / Mory

Mory is a local-first personal memory system. The current iOS app is centered on a write-first memory capture path: users can record a memory, attach multimodal evidence, arrange the resulting cards, save the facts locally, and let AI analysis run only when explicitly scheduled.

The current source of truth is the code plus the current system handbooks under `docs/mory_system_handbook/` and `docs/mory_system_handbook_zh/`. Older v3-v7 documents remain useful historical context, but they are not the primary status reference.

## Current Architecture

```text
Capture Draft
  -> RecordShell
  -> Artifact[]
  -> ArtifactSemanticDigest[]
  -> MemoryCardArrangement
  -> AffectSnapshot[]
  -> optional Analysis
  -> Graph / Arc / Reflection / Questions
```

| Layer | Purpose |
| --- | --- |
| `RecordShell` | The main memory fact: raw text, timestamps, capture source, provenance, mood/context, and artifact IDs. |
| `Artifact` | User or context material: text, photo, video, live photo, audio, link, music, place, weather, todo, document-like evidence. |
| `ArtifactSemanticDigest` | Structured media/text meaning such as OCR, captions, labels, transcript, duration, dimensions, and local identifiers. |
| `MemoryCardArrangement` | User visual expression: card refs, visual recipe, size token, order, stack/group, grid placement, nudge, rotation, z-index. |
| `AffectSnapshot` | Structured mood/affect evidence with explicit source tracking. |
| `Analysis` | Optional post-save intelligence. Arrangement is excluded from analysis input because it is visual expression, not semantic fact. |

Saving a memory does not mean AI analysis has started. The default local write path stores `.notScheduled`; only an explicit refresh policy moves the pipeline into `pending`, `running`, `completed`, or `failed`.

## Current Implementation Status

| Area | Current status |
| --- | --- |
| Local memory write path | Implemented: `RecordShell + Artifact[] + ArtifactSemanticDigest[] + MemoryCardArrangement + AffectSnapshot[]` are saved in one record-facts path. |
| Capture composer | Implemented: text, photo, video, live photo, audio, link, location, weather, music, todo, prompt answer, person context, affect, external capture, and Journaling Suggestions can seed the unified draft. |
| Card arrangement | Implemented: fixed 6-column logical grid, size tokens `stamp / strip / card / square / tape / banner`, visual recipes, stack/group, order, rotation/nudge/z-index. |
| Card rendering | Implemented: composer/detail render through the shared capture card path with `MemoryCardRecipeLayoutPolicy`, `MemoryCardObjectMetrics`, and recipe-specific object presentation. |
| Memory detail | Implemented: product viewing path uses arrangement-driven `MemoryDeskRenderer`; editing keeps arrangement mutation instead of rebuilding default layout. |
| Card Debug | Implemented: one `Card Debug` hub covers overview, type catalog, layout policy, visual recipes, grid board lab, card states/actions, arrangement reports, and fixture stress labs. |
| AI pipeline | Implemented: `/api/analyze` remains the analysis boundary; `AnalysisInputContract` includes `RecordShell`, ordered artifacts, and ordered semantic digests, and excludes arrangement. |
| Background/notifications | Wired: background orchestration, local notifications, push registration/enqueue/writeback, and notification management diagnostics exist; real-device behavior still needs field validation. |
| Product polish | In progress: Today/Memories/Insights information architecture, global status visibility, accessibility, localization QA, and release-quality visual polish are still open. |

## Code Structure

```text
mory/mory/
├── App/                              app entry, root shell, dependency setup
├── Domain/
│   ├── Capture/                      RecordShell, drafts, provenance
│   ├── Content/                      Artifact and semantic digest models
│   ├── Memory/                       snapshots, card arrangement, repository protocol
│   ├── Analysis/                     analysis contract and snapshots
│   ├── Graph/                        entity graph and links
│   └── Reflection/                   reflections and arcs
├── Features/
│   ├── Capture/                      unified composer and capture card components
│   ├── MemoryDetail/                 arrangement-driven memory desk and editor
│   ├── Home/                         Today shell and recent memories
│   ├── Memories/                     library, filters, timeline, search
│   ├── Insights/                     reflections, arcs, people, places, themes
│   ├── Settings/                     account, privacy, permissions, diagnostics
│   └── Shared/                       shared UI primitives
├── Infrastructure/
│   ├── Analysis/                     pipeline, API mapping, graph/reflection helpers
│   ├── Auth/                         Apple auth and Keychain session storage
│   ├── Capture/                      CaptureOrchestrator
│   ├── Context/                      location, weather, music, permissions
│   └── Networking/                   API client/configuration
├── Persistence/                      SwiftData stores, mappers, repositories, stack
└── Debug/                            diagnostics, Card Debug, quality and status labs

server/
├── cmd/server/                       Go backend entry point
├── internal/ai/                      AI provider abstraction
├── internal/auth/                    Apple auth and JWT issuance
├── internal/http/                    API handlers
├── internal/db/                      SQLite adapters
└── internal/subscription/            subscription service placeholder
```

## Capture And Cards

The current record layer is intentionally independent from AI:

- The composer owns the draft and `MemoryCardArrangementDraft`.
- Adding or removing content updates both staged artifacts and arrangement nodes.
- Size changes, stack/unstack, reorder, and delete are arrangement edits.
- `MemoryCaptureArtifactBuilder` returns artifacts, semantic digests, and draft-to-persisted artifact ID mapping.
- `MemoryCreationUseCase` persists facts first, then persists `.notScheduled` pipeline status.
- `MemoryMutationUseCase` updates artifacts, digests, arrangement, and affect data without defaulting over user layout.

Card layout uses a fixed 6-column logical grid across devices. The grid box is layout occupancy; card objects can render with their own visual ratio through `MemoryCardObjectMetrics`, but the visual size is not persisted as fact data.

## Debug Surfaces

The main card verification surface is `Card Debug`:

- `Overview`: recent memory four-layer health.
- `Type Catalog`: each content type and each supported size.
- `Layout Policy`: size token, grid box, density, and object metrics.
- `Visual Recipes`: all legal recipe/size combinations.
- `Grid Board Lab`: 6-column ordered sparse grid, placement, occupancy, drag/reorder experiments.
- `Card States & Actions`: composer/detail/debug roles, runtime states, and capability truth table.
- `Fixture Stress Lab`: legacy fixture pressure tests.

Debug surfaces are for engineering acceptance. They should not be treated as the final user-facing status design.

## AI Analysis Pipeline

AI is post-save and contract-bound:

- Save-only path writes local facts and `.notScheduled`.
- Explicit analysis builds `AnalysisInputContract`.
- Contract input includes `RecordShell`, ordered `Artifact[]`, and ordered `ArtifactSemanticDigest[]`.
- Contract input excludes `MemoryCardArrangement`.
- The app posts analysis work to `/api/analyze`.
- AI output is persisted as analysis/proposals/graph/reflection state; high-risk conclusions should remain reviewable.

The backend keeps provider selection behind the server boundary:

- `AI_PROVIDER=anthropic`
- `AI_PROVIDER=openai_compatible`
- `AI_PROVIDER=mock`

OpenAI-compatible vendors, including DeepSeek-style endpoints, integrate through backend configuration rather than direct client calls.

## Build And Verification

Preferred iOS compile checks use generic simulator destinations so validation does not depend on opening or switching a specific simulator:

```sh
xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'generic/platform=iOS Simulator' build
xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'generic/platform=iOS Simulator' build-for-testing
```

Useful static checks:

```sh
git diff --check
jq empty mory/mory/Localizable.xcstrings
```

Backend tests:

```sh
cd server
/Users/z14/sdk/go1.26.3/bin/go test ./...
```

## Backend

Backend lives in `server/` and deploys independently from the iOS app.

- Fly config: `fly.toml`
- Docker build: `server/Dockerfile`
- Deployment notes: `server/DEPLOY_FLY.md`
- OpenAPI: `server/openapi.yaml`

Default conservative deployment:

```text
AI_MODE=mock
AI_PROVIDER=mock
DEV_AUTH_ENABLED=false
APNS_ENABLED=false
```

To enable live AI, set `AI_MODE=live` and configure `AI_PROVIDER`, `AI_MODEL`, `AI_API_KEY`, and `AI_BASE_URL` for the selected provider.

Remote push delivery:

- `/api/push/register` stores APNs tokens plus notification and intelligence preferences.
- `/api/push/enqueue` queues remote notification intents.
- Real APNs sending uses token auth with `APNS_ENABLED=true`, `APNS_ENVIRONMENT`, `APNS_TOPIC`, `APNS_KEY_ID`, `APNS_TEAM_ID`, and either `APNS_AUTH_KEY_PATH` or `APNS_AUTH_KEY`.
- `GET /metrics` emits request counters, AI operation counters/tokens/errors, and push delivery worker counters.

## Immediate Next Work

1. Real-device verification for Apple login, Photos, microphone, Speech, Location, WeatherKit, MusicKit, background tasks, and APNs.
2. Product-level intelligence/status surface: analysis ready, failed, retry, proposal review, imports, and source provenance.
3. Composer/detail card interaction polish after Debug acceptance: drag/reorder, state/action consistency, accessibility, and localization QA.
4. Today/Home board design on top of the same 6-column card layout vocabulary.
5. Link metadata completion, video playback/detail polish, prompt/person/affect presentation refinement.
6. Release hardening: privacy copy, export/delete QA, entitlement gating, backend monitoring, and focused regression coverage.

## Documentation

- [Current system handbook](docs/mory_system_handbook/)
- [Current Chinese system handbook](docs/mory_system_handbook_zh/)
- [Historical v7 docs](docs/mory_v7/)
- [Historical v6 docs](docs/mory_v6/)
- [Historical v5 docs](docs/mory_v5/)
- [Historical v4 docs](docs/mory_v4/)
- [Historical v3 docs](docs/mory_v3/)

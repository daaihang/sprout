# Sprout

Sprout is a local-first personal memory system. The current `mory/` iOS app is built on the **Mory v3/v4 memory architecture** and has started landing the **Mory v5 product shell**.

v3 established the five-layer memory ontology and end-to-end analysis loop. v4 extends that system with multimodal capture, save-before context candidates, persistent authentication, quality gates, and real Today board data. v5 is the UI/UX productization pass for public beta.

## Architecture

```text
Capture -> Artifact -> Composition -> Analysis Snapshot -> Graph -> Temporal Arc -> Reflection
```

| Layer | Purpose |
|-------|---------|
| **Capture** | User input draft and save orchestration via `MemoryCaptureDraft` / `CaptureOrchestrator` |
| **Artifact** | Raw memory material: text, photo, audio, weather, location, music, link, todo, document |
| **Composition** | Today board composition and card preferences via `CompositionItem` / `HomeBoardItemPreference` |
| **Analysis Snapshot** | AI-generated summary, entities, retrieval terms, salience, and reflection hints |
| **Graph** | Entity nodes, entity edges, and artifact-entity links |
| **Temporal Arc** | Storyline candidates promoted from related memory clusters |
| **Reflection** | AI-generated insights with source records/artifacts |

The ontology is still v3-compatible. v4 adds richer artifact inputs and context capture without changing the downstream Graph -> Arc -> Reflection model.

## Current Implementation Status

Current code is closest to **v4 Beta 2+ plus v5 alpha shell**. Most v4 implementation work exists in code; the remaining work is real-device verification, quality tuning, and product polish.

| Area | Current status |
|------|----------------|
| Auth persistence | Implemented: Apple auth, Keychain credential storage, access-token refresh |
| AI request contract | Implemented: `record_aggregate.v1` payload with record shell, artifacts, known entities, debug options |
| Photo capture | Implemented: Photos picker, Vision classification/OCR, thumbnail, artifact text for analysis |
| Audio capture | Implemented: recorder state machine, Speech transcription, editable transcript, audio artifact |
| Link capture | Implemented: URL detection and LinkPresentation metadata preview; `og:image` URL extraction is still limited |
| Auto context | Implemented: save-before location/weather/music candidates with user selection |
| Home / Today board | Implemented: real memory, accepted arc, reflection, context cluster, pending-action, system cards |
| Quality gates | Implemented: entity, arc, and reflection gates plus Quality Tuning Lab and opt-in local batch |
| v5 navigation shell | Implemented: Today / Memories / Insights tabs, bottom quick capture toolbar, Settings entry |
| v5 settings/privacy | Implemented baseline: account, permissions, privacy, data controls, capture preferences, appearance/language, internal diagnostics |
| Public beta polish | In progress: visual refinement, accessibility QA, localization QA, real-device permission testing |

The older v4 phase table has been superseded by `docs/mory_v4/STATUS_2026-05-17.md`.

## Code Structure

```text
mory/mory/
├── App/
│   ├── MoryApp.swift                 — app entry, auth gate, dependency setup
│   ├── MoryRootView.swift            — v5 three-tab shell and quick capture presentation
│   ├── AppNavigation.swift           — tab and settings routes
│   └── MoryAppDependencies.swift     — environment dependencies
├── Domain/
│   ├── Analysis/                     — RecordAnalysisSnapshot
│   ├── Capture/                      — RecordShell
│   ├── Composition/                  — Board, Composition, HomeBoardRuleEngine
│   ├── Content/                      — Artifact
│   ├── Graph/                        — EntityNode, EntityEdge, ArtifactEntityLink
│   ├── Memory/                       — presentation snapshots, drafts, repository protocol
│   └── Reflection/                   — ReflectionSnapshot
├── Features/
│   ├── Capture/                      — composer, quick text, quick voice, photo/audio/link/location components
│   ├── Home/                         — Today board and recent memories
│   ├── Memories/                     — library, filters, timeline/search entry points
│   ├── Insights/                     — storylines, reflections, people, places, themes, decisions
│   ├── MemoryDetail/                 — source artifacts, analysis, rerun/edit/delete actions
│   ├── Settings/                     — account, permissions, privacy, export/delete/preferences
│   ├── Auth/                         — sign-in UI
│   └── Shared/                       — public empty states and shared UI
├── Infrastructure/
│   ├── Analysis/
│   │   ├── Artifacts/                — PhotoArtifactProcessor, AudioTranscriptionService, LinkMetadataExtractor
│   │   ├── Graph/                    — GraphUpdater and graph/search query services
│   │   ├── Pipeline/                 — request/response mapping, remote analysis, pipeline executor
│   │   ├── Quality/                  — entity/arc/reflection quality policies
│   │   └── Temporal/                 — arc candidate, promoter, merge, reflection services
│   ├── Auth/                         — AppleAuthService, AuthSessionManager, KeychainCredentialStore
│   ├── Capture/                      — CaptureOrchestrator
│   ├── Context/                      — location, weather, music, permissions, auto collector
│   └── Networking/                   — API client/configuration
├── Persistence/
│   ├── Models/                       — SwiftData stores
│   ├── Mappers/                      — domain/store mapping
│   ├── Repositories/                 — MoryMemoryRepository
│   └── Stack/                        — SwiftData container setup
└── Debug/                            — internal diagnostics and Quality Tuning Lab

server/
├── cmd/server/                       — Go backend entry point
├── internal/ai/                      — AI provider abstraction
├── internal/auth/                    — Apple auth and JWT issuance
├── internal/http/                    — API handlers and server
├── internal/db/                      — local persistence adapters
└── internal/subscription/            — subscription service placeholder
```

## App Shell

The current public app shell is defined in `MoryRootView`:

1. **Today** — live board, recent memories, pipeline states.
2. **Memories** — library filters, timeline, search, memory detail.
3. **Insights** — storylines, reflections, people, places, themes, decisions.

A bottom quick capture toolbar is available across tabs:

- Text capture opens `QuickTextCaptureView`.
- Press-hold voice capture records and transcribes before review.
- More capture opens the full `CaptureComposerView`.

Settings is available from the top-right account button. Internal diagnostics are only shown when `AppRuntimeEnvironment.allowsDebugTools` is true.

## Authentication

Authentication is handled by `AuthSessionManager` in `mory/mory/Infrastructure/Auth/AuthSessionManager.swift`.

- Sign in with Apple posts to `/auth/apple`.
- Sessions are stored in iOS Keychain via `KeychainCredentialStore`.
- `MoryAuthTokenProvider` refreshes access tokens before analysis requests.
- Debug/development guest credentials are supported for local workflows.
- The app entry point switches directly between loading, authenticated, and unauthenticated states in `MoryApp`.

## Capture And Context

Capture now supports:

- Text.
- Photo with local Vision classification/OCR and thumbnail generation.
- Audio with local Speech transcription and editable transcript.
- Link with URL detection and LinkPresentation preview metadata.
- Manual location selection.
- Save-before context candidates for location, weather, and music.

Context is collected before save, shown to the user, and saved only if selected. The app does not append late context after the initial memory snapshot.

## AI Analysis Pipeline

AI analysis is record-aggregate based.

- Signed-in capture analysis posts to `/api/analysis/records`.
- Payload carries `schema_version`, `analysis_reason`, `record_shell`, `artifacts`, `known_entities`, and optional debug options.
- iOS maps the server response into `RecordAnalysisSnapshot`.
- The local pipeline then updates graph links, promotes temporal arcs, and requests/stores reflections when quality gates pass.

The current pipeline is intentionally ordered:

```text
Analyze -> Persist analysis -> Graph update -> Arc promotion -> Reflection request/store
```

Reflection is not started in parallel with Analyze because it depends on analysis salience, entities, gates, and reflection hints.

The backend keeps AI provider selection behind the server boundary:

- `AI_PROVIDER=anthropic`
- `AI_PROVIDER=openai_compatible`
- `AI_PROVIDER=mock`

OpenAI-compatible vendors, including DeepSeek-style endpoints, integrate through backend configuration rather than direct client calls.

## Home Board

Today uses `HomeBoardRuleEngine` and real repository data. It can render:

- Memory cards.
- Accepted storyline cards.
- Suggested reflection cards.
- Context cluster cards.
- Pending or failed processing cards.
- System prompt cards.

Local user preferences support pin, hide, and dismiss actions through `HomeBoardItemPreference`.

## Build

Preferred verification command:

```sh
xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Filtered output:

```sh
xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | rg -n 'error:|warning:|BUILD SUCCEEDED|BUILD FAILED'
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
```

To enable live AI, set `AI_MODE=live` and configure `AI_PROVIDER`, `AI_MODEL`, `AI_API_KEY`, and `AI_BASE_URL` for the selected provider.

Local DeepSeek-compatible setup:

1. Create `server/.env` from `server/.env.example`.
2. Set `AI_API_KEY=your_key`.
3. Keep:
   - `AI_MODE=live`
   - `AI_PROVIDER=openai_compatible`
   - `AI_MODEL=deepseek-chat`
   - `AI_BASE_URL=https://api.deepseek.com`
   - `JWT_TTL=1h`
4. Run:

```sh
set -a && source server/.env && set +a && go run ./server/cmd/server
```

The backend normalizes `AI_BASE_URL` to the correct OpenAI-compatible chat completions endpoint automatically.

## Immediate Next Work

1. **Real-device verification** — Apple login persistence, Photos, Microphone, Speech, Location, WeatherKit, and MusicKit.
2. **Link metadata completion** — add richer description and explicit `og:image` URL extraction where LinkPresentation does not expose it.
3. **AI latency and traceability** — record stage timing and decide whether any remaining >15s path blocks beta.
4. **v5 visual/product polish** — refine Today, Memories, Insights, Settings, empty states, accessibility, and localization.
5. **Project health** — split large files called out in `docs/mory_v5/Architecture/09_project_structure_health.md`.
6. **Quality tuning** — run local core batch against the Go server and expand realistic samples before RC.

## Documentation

- [Mory v3 docs](docs/mory_v3/) — ontology, domain model, AI/graph/reflection contracts.
- [Mory v4 docs](docs/mory_v4/) — multimodal capture, context, auth, speed, quality, real-device status.
- [Mory v4 current status](docs/mory_v4/STATUS_2026-05-17.md) — most accurate v4 implementation and verification snapshot.
- [Mory v5 docs](docs/mory_v5/) — public beta product shell, presentation architecture, settings/privacy, acceptance gates.

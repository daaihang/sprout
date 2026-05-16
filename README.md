# Sprout

Sprout is a local-first personal memory system built on **Mory v4**.

The v3 release established the five-layer memory ontology and end-to-end pipeline. The v4 release extends the system with multimodal inputs (photos, audio, music, weather, location, links), automated context collection, AI speed optimization, and persistent authentication.

## Architecture

```
Artifact → Composition → Analysis Snapshot → Graph → Temporal Arc → Reflection
```

| Layer | Purpose |
|-------|---------|
| **Artifact** | Raw capture content: text, photo, audio, weather, location, music, link |
| **Composition** | Board/day layout state persisted via `CompositionItemState` |
| **Analysis Snapshot** | AI-generated summary, entities, and reasoning from `RecordAnalysisSnapshot` |
| **Graph** | Entity nodes and relationships via `EntityNode` / `EntityEdge` |
| **Temporal Arc** | Storyline candidates promoted from related memories via `TemporalArc` |
| **Reflection** | AI-generated insights surfaced via `ReflectionSnapshot` |

v4 does **not** change this ontology. It extends Artifact from "text only" to "photo / audio / weather / location / music / link", each with corresponding AI processing rules and automated collection.

## Current Implementation Status

v4 is being implemented across 8 phases. Phase 0 and Phase 1 are complete.

| Phase | Content | Status |
|-------|---------|--------|
| Phase 0 | Auth persistence (Apple login + Keychain token refresh) | **Complete** |
| Phase 1 | AI speed optimization (parallel pipeline + prompt trimming) | **Complete** |
| Phase 2 | Photo AI parsing (Vision → text artifact → analyze) | Pending |
| Phase 3 | Audio transcription (Speech → rawText → analyze) | Pending |
| Phase 4 | Automated context collection (weather / location / music) | Pending |
| Phase 5 | Link URL preview (metadata extraction → link artifact) | Pending |
| Phase 6 | Home board data connection (real memory / arc / reflection cards) | Pending |
| Phase 7 | AI content governance (entity deduplication, arc coherence, reflection quality) | Pending |

**Total estimated effort: ~14 days**

Release milestones:
- `v4.0-alpha.1`: Phase 0 + 1 → ready
- `v4.0-alpha.2`: Phase 0–3 → multimodal input ready
- `v4.0-beta.1`: Phase 0–4 → context-aware capture ready
- `v4.0-beta.2`: Phase 0–6 → homepage fully live
- `v4.0`: Phase 0–7 → all features delivered

## Code Structure

```
mory/mory/
├── App/
│   └── ...App entry point
├── Domain/
│   ├── Analysis/      — RecordAnalysisSnapshot, ReflectionSnapshot
│   ├── Capture/       — Capture drafts, artifact building
│   ├── Composition/   — Board/day layout state
│   ├── Content/       — Artifact, RecordShell, EntityNode, EntityEdge
│   ├── Graph/         — Entity graph models
│   └── Reflection/    — Reflection models
├── Features/
│   ├── Arcs/          — Temporal arc browsing
│   ├── Auth/          — Apple login, Keychain-backed sessions
│   ├── Capture/       — CaptureComposerView (Phase 2–5: multimodal + auto-context)
│   ├── Entities/      — People/entity detail views
│   ├── Home/          — HomeScreen (Phase 6: real data cards)
│   ├── MemoryDetail/  — Memory detail with artifact evidence
│   ├── People/        — People tab
│   ├── Reflections/   — Reflection browsing
│   ├── Search/        — Search functionality
│   └── Timeline/      — Timeline view
├── Infrastructure/
│   ├── Analysis/
│   │   ├── AnalyzeRequestBuilder.swift          (extended for v4 artifacts)
│   │   ├── ArchitecturePipelineExecutor.swift    (Phase 1: parallelized)
│   │   └── MemoryCaptureArtifactBuilder.swift
│   ├── Auth/
│   │   ├── AppleAuthService.swift                (Phase 0: persistence added)
│   │   └── KeychainCredentialStore.swift         (Phase 0: token refresh added)
│   └── Networking/  — API client, server handlers
├── Persistence/      — SwiftData models (Record, CompositionItemState, MediaCard)
└── Debug/            — Debug diagnostics

server/
├── cmd/server/        — Go backend entry point
├── internal/ai/       — AI provider abstraction (anthropic / openai_compatible)
├── internal/auth/     — Apple auth, JWT issuance
└── internal/handlers/ — API endpoints (analysis, onboarding)
```

## Authentication

Handled by `AuthSessionManager` in `mory/mory/Features/Auth/AuthSessionManager.swift`.

- Sign in with Apple posts to `/auth/apple`
- Sessions stored in iOS Keychain via `KeychainCredentialStore` (mory app)
- `development_stub` mode bypasses backend auth during development
- Onboarding completion posts to `/api/me/onboarding/complete`

Phase 0 completion (c75267df):
- Apple login tokens persist across cold starts — no re-login required
- JWT refresh is handled by `KeychainCredentialStore`

The app flows through `AuthGateView`:

1. Welcome
2. Anonymous onboarding preview
3. Signed-in onboarding
4. Signed-in main app

## AI Analysis Contract

AI analysis is record-aggregate based.

- Onboarding preview posts to `/api/analysis/preview`
- Signed-in capture analysis posts to `/api/analysis/records`
- Payload carries `schema_version`, `analysis_reason`, `record_shell`, `artifacts`, and `known_entities`
- iOS maps response into `RecordAnalysisSnapshot`, then uses local services to update graph and reflection state

Phase 1 completion (292c01b1):
- `ArchitecturePipelineExecutor` runs Analyze and Reflection in parallel (~53s → <15s)
- Prompts trimmed for speed
- NotificationCenter replaces polling for analysis completion

The backend keeps AI provider abstraction behind the server boundary:
- `AI_PROVIDER=anthropic`
- `AI_PROVIDER=openai_compatible`

OpenAI-compatible vendors (DeepSeek, etc.) integrate through backend configuration, not direct client calls.

## Home Board

The home experience is transitioning from container-first UI to persistent composition.

- `ContainerSpan` remains the visible placement unit
- `StickerGridLayout` still renders the board
- `CompositionItemState` is the primary persisted resize state for board items
- Board refreshes immediately on card resize
- Capture timestamps use real capture time (not backfilled to page's 23:59)

Phase 6 target: Today Board renders real memory / arc / reflection cards instead of empty states.

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

Default conservative deployment (no live AI):

```
AI_MODE=mock
AI_PROVIDER=mock
DEV_AUTH_ENABLED=false
```

To enable live AI, set `AI_MODE=live` and configure `AI_PROVIDER`, `AI_MODEL`, `AI_API_KEY`, and `AI_BASE_URL` for OpenAI-compatible endpoints.

Local DeepSeek setup:

1. Create `server/.env` from `server/.env.example`
2. Set `AI_API_KEY=your_key`
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

## Immediate Next Work (Phase 2–7)

1. **Phase 2** — Photo AI parsing: implement `PhotoArtifactProcessor` using Vision, integrate into `CaptureComposerView`, extend `AnalyzeRequestBuilder`
2. **Phase 3** — Audio transcription: implement `AudioTranscriptionService` using Speech framework, add editable transcription UI
3. **Phase 4** — Automated context: implement weather / location / music context services, add `ContextAutoCollector`
4. **Phase 5** — Link preview: implement `LinkMetadataExtractor`, extract og:title / og:image in `CaptureComposerView`
5. **Phase 6** — Home board connection: wire real memory / arc / reflection data into `HomeScreen`, remove empty-state fallbacks
6. **Phase 7** — AI content governance: entity deduplication in `GraphUpdater`, quality filtering in `TemporalArcPromoter`, storyline coherence in `TemporalArcCandidateBuilder`

## Documentation

Full v4 specification: [`docs/mory_v4/`](../docs/mory_v4/)

- [PRD Index](../docs/mory_v4/PRD/00_v4_prd_index.md) — product scope and goals
- [Architecture Index](../docs/mory_v4/Architecture/00_v4_architecture_index.md) — technical architecture
- [Build Roadmap](../docs/mory_v4/Architecture/07_build_roadmap.md) — phase-by-phase implementation plan
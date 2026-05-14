# Sprout

Sprout is currently in the Mory v3 migration: from a record-centric journaling app toward a local-first personal memory system.

The target architecture is:

`Artifact -> Composition -> Analysis Snapshot -> Graph -> Temporal Arc -> Reflection`

The codebase already contains most of these layers, but they are still being progressively wired together and old `Record`-centric paths are still being removed.

## Current Shape

- `sprout/sprout/Models`
  SwiftData models for legacy capture objects and transition-era persisted layout objects such as `Record`, `MediaCard`, and `CompositionItemState`.
- `sprout/sprout/Shared/Memory`
  v3 memory-domain models including `Artifact`, `RecordShell`, `RecordAnalysisSnapshot`, `ReflectionSnapshot`, `EntityNode`, `EntityEdge`, `ArtifactEntityLink`, and `TemporalArc`.
- `sprout/sprout/Services`
  Aggregate building, composition projection, parsing, AI-response mapping, repositories, external integrations, auth, and subscriptions.
- `sprout/sprout/Cards`
  SwiftUI renderers for memory surfaces. These are being gradually repositioned from old business-card components into artifact/composition renderers.
- `sprout/sprout/Views`
  Main screens, capture flows, detail pages, onboarding, and home navigation.
- `server/`
  Go backend for auth, lightweight user state, and AI provider orchestration.

## Migration Status

Practical progress against the v3 roadmap:

- Phase 0 `100%`
  Ontology and architecture docs are frozen.
- Phase 1 `92%`
  Artifact layer exists and modern capture paths already dual-write aggregate data.
- Phase 2 `95%`
  Composition state persists by board/day, board resize now refreshes immediately, and the home projection path now renders artifact-backed composition items directly.
- Phase 3 `93%`
  Analysis snapshot contract and local persistence are active.
- Phase 4 `84%`
  Graph models and update logic exist, but UI consumption is still partial.
- Phase 5 `86%`
  Temporal arcs and phase reflections exist, but the page-level user experience is still incomplete.
- Phase 6 `98%`
  Legacy cleanup is deep into physical removal; old per-record span fields, override storage, and `cardType` have been removed from `Record`.

Main remaining gaps:

- Several card internals still present legacy UI quality or legacy assumptions.
- `MediaCard` now exists only as binary payload backing for photo/audio renderers, but other non-home legacy consumers still need to be audited and cut off from old `Record` truth paths.
- Graph and arc layers are not yet fully exposed as first-class navigation experiences.

Recent high-frequency card refreshes already completed:

- `QuoteCard`
- `PhotoCard`
- `PhaseReflectionCard`
- `MusicCard`
- `PeopleCard`
- `MapCard`

## Authentication

Authentication is handled by `AuthSessionManager` in [sprout/sprout/Services/AuthSessionManager.swift](/Users/z14/Documents/sprout/sprout/sprout/Services/AuthSessionManager.swift).

- Sign in with Apple posts to `/auth/apple`.
- Sessions are stored in the iOS Keychain under `com.speculolabs.sprout.auth`.
- `development_stub` mode can bypass backend auth during development.
- Signed-in onboarding completion posts to `/api/me/onboarding/complete`.

The app flows through `AuthGateView`:

1. Welcome
2. Anonymous onboarding preview
3. Signed-in onboarding
4. Signed-in main app

## AI Analysis Contract

AI analysis is now record-aggregate based.

- Onboarding preview posts to `/api/analysis/preview`.
- Signed-in capture analysis posts to `/api/analysis/records`.
- The payload carries `schema_version`, `analysis_reason`, `record_shell`, `artifacts`, and `known_entities`.
- iOS maps the response into `RecordAnalysisSnapshot`, then uses deterministic local services to update graph and reflection state.

The Go backend keeps AI provider abstraction behind the server boundary.

- `AI_PROVIDER=anthropic`
- `AI_PROVIDER=openai_compatible`

OpenAI-compatible vendors such as DeepSeek should be integrated through backend configuration, not by direct client calls.

## Home Board

The home experience is moving from container-first UI toward persistent composition.

- `ContainerSpan` remains the visible placement unit.
- `StickerGridLayout` still renders the board.
- `CompositionItemState` is now the primary persisted resize state for board items.
- The current day board refreshes immediately when a user changes card size.
- Capture timestamps now use real capture time again instead of backfilling non-today entries to the selected page's `23:59`.

This matters because v3 treats:

- `Record` as a capture event
- `Composition` as persistent layout meaning

not as page-local hacks.

## Record Storage

`Record` still currently stores:

- Base content such as `body`, `createdAt`, `updatedAt`, `tags`
- Remaining transitional fields such as `dashboardOrder`
- Weather and location snapshot fields
- Transitional relationships around `MediaCard` for photo/audio payload backing and some older related objects

That is transitional, not final.

The intended direction is:

- `Record` becomes a capture shell
- `Artifact` becomes content truth
- `CompositionItemState` becomes board layout truth
- `RecordAnalysisSnapshot` / `ReflectionSnapshot` become AI truth

Current detail-page truth after this round:

- `RecordDetailView` now resolves `text/photo/audio/link/todo/music/map/weather/people` from `memoryView.artifacts` first.
- AI entity evidence is surfaced directly in people/detail evidence areas.
- `RecordTimelineView` and `TodayInHistoryCard` now use a shared `RecordEvidenceProjector`, so preview kind, headline, subtitle, and meta labels come from the same artifact-backed evidence path as detail.
- `Record` and `MediaCard` are retained only as compatibility fallback for older rows and photo/audio payload lookup.

## Subscription System

Subscriptions are managed by `SubscriptionManager`.

- RevenueCat is the primary subscription backend when linked.
- StoreKit is the fallback path.
- If RevenueCat is unavailable in a local build, subscription handling is stubbed.

## Build

Preferred verification command:

```sh
xcodebuild -project sprout/sprout.xcodeproj -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

For filtered output:

```sh
xcodebuild -project sprout/sprout.xcodeproj -scheme sprout -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | rg -n 'error:|warning:|BUILD SUCCEEDED|BUILD FAILED'
```

## Backend

The backend lives in `server/` and is deployed independently from the iOS app.

- Fly config: [fly.toml](/Users/z14/Documents/sprout/fly.toml)
- Docker build: [server/Dockerfile](/Users/z14/Documents/sprout/server/Dockerfile)
- Deployment notes: [server/DEPLOY_FLY.md](/Users/z14/Documents/sprout/server/DEPLOY_FLY.md)

Default conservative deployment mode:

- `AI_MODE=mock`
- `AI_PROVIDER=mock`
- `DEV_AUTH_ENABLED=false`

To switch to live AI:

- set `AI_MODE=live`
- choose `AI_PROVIDER=anthropic` or `openai_compatible`
- provide `AI_MODEL`
- provide `AI_API_KEY`
- provide `AI_BASE_URL` when using a non-default OpenAI-compatible endpoint

Local DeepSeek setup for immediate testing:

1. Create `server/.env` from [server/.env.example](/Users/z14/Documents/sprout/server/.env.example).
2. Put your key in `AI_API_KEY=...`.
3. Keep:
   - `AI_MODE=live`
   - `AI_PROVIDER=openai_compatible`
   - `AI_MODEL=deepseek-v4-pro`
   - `AI_BASE_URL=https://api.deepseek.com`
4. Run the backend from repo root:

```sh
set -a && source server/.env && set +a && go run ./server/cmd/server
```

The backend will normalize `AI_BASE_URL=https://api.deepseek.com` to the correct OpenAI-compatible chat completions endpoint automatically.

## Immediate Next Work

The current best-practice next steps are:

1. Replace remaining search/list/detail auxiliary preview helpers with shared artifact-backed evidence projection.
2. Refresh the remaining high-frequency card internals and detail layouts so artifact-backed content also looks intentional.
3. Surface graph and phase objects more directly in navigation and detail views.
4. Add a dedicated backend Reflection API while keeping iOS local-first.
